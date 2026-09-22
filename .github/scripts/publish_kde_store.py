#!/usr/bin/env python3
"""
Publish a release (file + changelog + version bump) to store.kde.org
(OpenDesktop / Pling).

There is no writable official API for this (the OCS API is read-only for
content editing), so this scrapes the product edit page's HTML forms the
same way a browser session would.

The product description is intentionally NOT touched by this script: it's
edited by hand on the store page and left as-is on every publish (fetched
read-only via the public OCS API and resubmitted unchanged, since the edit
form requires a description value in the same POST that sets the version).

Both opendesktop.org and store.kde.org sit behind an Anubis bot-check
(https://github.com/TecharoHQ/anubis) that gates every request until a small
proof-of-work is solved; AnubisSession below solves it transparently, so
login is still plain scripted username/password - no browser needed.

Requires environment variables:
  KDE_STORE_USER - your store.kde.org / opendesktop email/username
  KDE_STORE_PASSWORD - your store.kde.org / opendesktop password
"""

import os
import sys
import re
import json
import time
import hashlib
import datetime
import argparse
from urllib.parse import urljoin, parse_qs, urlparse
import requests

# https://store.kde.org/p/2350434 - Fancy Tasks NG
# Category: Linux/Unix Desktops > Desktop Extensions > KDE Plasma Extensions
#           > Plasma 6 Extensions > Plasma 6 Applets (read dynamically below;
#           this is just for reference).
DEFAULT_PRODUCT_ID = "2350434"
OCS_READ_API = "https://api.opendesktop.org/ocs/v1/content/data"
DEFAULT_METADATA_PATH = "package/metadata.json"
DEFAULT_ASSET_NAME = "FancyTasksNG.plasmoid"
KDE_STORE_BASE = "https://store.kde.org"
OPENDESKTOP_LOGIN_URL = "https://www.opendesktop.org/login/"
OPENDESKTOP_OAUTH_LOGIN = "https://store.kde.org/oauth/login/"

# Current tag set on the listing; the edit form has no reliable way to read
# existing tags back, so they're resubmitted verbatim on every publish.
PRODUCT_TAGS = ["kde-plasma-6", "panel", "plasma-6.5", "plasma-6.6", "taskbar", "plasma-6.7"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:157.0) Gecko/20100101 Firefox/157.0',
    'Accept-Language': 'en-US,en;q=0.9',
    'DNT': '1',
}

VERBOSE = False


def log_debug(msg):
    if VERBOSE:
        print(f"[DEBUG] {msg}")


def log_http_response(res, label="HTTP Response"):
    print(f"\n=== {label} ===")
    print(f"URL: {res.url}")
    print(f"Status Code: {res.status_code}")
    print(f"Response Headers:\n{res.headers}")
    print(f"Response Body (first 3000 chars):\n{res.text[:3000]}")
    print("=" * (len(label) + 8) + "\n")


def extract_input_value(html, field_name):
    """Extract input field value from HTML form."""
    patterns = [
        rf'<input\s+[^>]*name=["\']{field_name}["\']\s+[^>]*value=["\']([^"\']*)["\']',
        rf'<input\s+[^>]*value=["\']([^"\']*)["\']\s+[^>]*name=["\']{field_name}["\']',
    ]
    for pattern in patterns:
        match = re.search(pattern, html, re.IGNORECASE)
        if match:
            return match.group(1)
    return ""


def extract_all_inputs(html):
    """Extract all input name-value pairs from an HTML string."""
    inputs = {}
    pattern = r'<input\s+([^>]+)>'
    for match in re.finditer(pattern, html, re.IGNORECASE):
        attrs = match.group(1)
        name_match = re.search(r'name=["\']([^"\']+)["\']', attrs, re.IGNORECASE)
        value_match = re.search(r'value=["\']([^"\']*)["\']', attrs, re.IGNORECASE)
        if name_match:
            name = name_match.group(1)
            val = value_match.group(1) if value_match else ""
            inputs[name] = val
    return inputs


def fetch_current_description(product_id):
    """Read the product's current description via the public, read-only OCS API.

    Returned verbatim and resubmitted unchanged in update_product_metadata() -
    this script never edits the description, only reads it back so the
    version-bump POST doesn't have to touch it.
    """
    url = f"{OCS_READ_API}/{product_id}?format=json"
    log_debug(f"GET {url}")
    res = requests.get(url, headers=HEADERS, timeout=15)
    res.raise_for_status()
    data = res.json()
    entries = data.get('data') or []
    if not entries:
        print(f"Warning: OCS API returned no data for product {product_id}; description will be left blank.", file=sys.stderr)
        return ''
    return entries[0].get('description', '')


def solve_anubis_pow(random_data, difficulty):
    """Solve an Anubis proof-of-work challenge: find a nonce such that
    SHA256(random_data + nonce) starts with `difficulty` zero hex nibbles.
    Matches the reference algorithm in Anubis's worker/sha256-*.mjs."""
    zero_bytes = difficulty // 2
    odd = difficulty % 2 != 0
    nonce = 0
    while True:
        digest = hashlib.sha256(f"{random_data}{nonce}".encode()).digest()
        ok = all(b == 0 for b in digest[:zero_bytes])
        if ok and odd and digest[zero_bytes] >> 4 != 0:
            ok = False
        if ok:
            return digest.hex(), nonce
        nonce += 1


def solve_anubis_challenge(session, url, html):
    """Solve an Anubis bot-check page (opendesktop.org and store.kde.org each
    run their own instance) and fetch the resulting short-lived auth cookie."""
    base_prefix = re.search(r'anubis_base_prefix"\s+type="application/json">"([^"]*)"', html).group(1)
    challenge = json.loads(re.search(r'anubis_challenge"\s+type="application/json">(\{.*?\})\s*</script>', html, re.S).group(1))
    rules, ch = challenge['rules'], challenge['challenge']
    start = time.time()
    response_hash, nonce = solve_anubis_pow(ch['randomData'], rules['difficulty'])
    elapsed_ms = int((time.time() - start) * 1000)
    log_debug(f"Solved Anubis challenge (difficulty={rules['difficulty']}) in {elapsed_ms}ms")
    pass_url = urljoin(url, f"{base_prefix}/.within.website/x/cmd/anubis/api/pass-challenge")
    session.get(pass_url, params={
        'id': ch['id'], 'response': response_hash, 'nonce': str(nonce),
        'redir': url, 'elapsedTime': str(elapsed_ms),
    }, headers=HEADERS, allow_redirects=False)


class AnubisSession(requests.Session):
    """A requests.Session that transparently solves Anubis bot-checks so
    every existing session.get()/session.post() call site keeps working
    unchanged."""

    def request(self, method, url, **kwargs):
        res = super().request(method, url, **kwargs)
        if 'id="anubis_challenge"' in res.text:
            solve_anubis_challenge(self, res.url, res.text)
            res = super().request(method, url, **kwargs)
        return res


def login(session, username, password):
    """Authenticate with opendesktop.org and return session for store.kde.org."""
    print("Initiating login flow...")

    session.cookies.set('verified', '1', domain='www.opendesktop.org')
    session.cookies.set('verified', '1', domain='store.kde.org')

    oauth_start_url = f"{OPENDESKTOP_OAUTH_LOGIN}?redirect=DR3D_sCP7lO1HeXHkP9cjUtETUM3ZGhjbkhDZO8SgFxOQwBoXE6J8chmyjY~"
    log_debug(f"GET {oauth_start_url}")
    res = session.get(oauth_start_url, headers=HEADERS, allow_redirects=True)
    log_debug(f"OAuth login GET final URL: {res.url}, status: {res.status_code}")
    res.raise_for_status()

    login_html = res.text
    csrf = extract_input_value(login_html, 'csrf')
    twit = extract_input_value(login_html, 'twit')
    redirect_url = extract_input_value(login_html, 'redirect_url')

    if not csrf:
        log_debug(f"CSRF not found, trying GET {OPENDESKTOP_LOGIN_URL}")
        res = session.get(OPENDESKTOP_LOGIN_URL, headers=HEADERS, allow_redirects=True)
        login_html = res.text
        csrf = extract_input_value(login_html, 'csrf')
        twit = extract_input_value(login_html, 'twit')
        redirect_url = extract_input_value(login_html, 'redirect_url')

    if not csrf:
        print("Error: Could not extract CSRF token from login page.", file=sys.stderr)
        log_http_response(res, "Login Page HTML Response")
        sys.exit(1)

    log_debug(f"Extracted CSRF token: {csrf[:15]}...")

    fake_fp = "5df9b02ed58579563e2a91b8d9489c97"
    fake_fpv3 = "5dcbcec3bf4b14dc05fbb2ae136ff5ac"
    twit_val = f'"{fake_fp}_{fake_fpv3}"'

    login_data = {
        'email': username,
        'password': password,
        'redirect_url': redirect_url or '',
        'csrf': csrf,
        'twit': twit_val,
    }

    post_headers = HEADERS.copy()
    post_headers['Content-Type'] = 'application/x-www-form-urlencoded'
    post_headers['Origin'] = 'https://www.opendesktop.org'
    post_headers['Referer'] = 'https://www.opendesktop.org/login/'
    post_headers['Sec-Fetch-Dest'] = 'document'
    post_headers['Sec-Fetch-Mode'] = 'navigate'
    post_headers['Sec-Fetch-Site'] = 'same-origin'

    print(f"Logging in as {username}...")
    login_res = session.post(OPENDESKTOP_LOGIN_URL, data=login_data, headers=post_headers, allow_redirects=False)
    log_debug(f"Login POST status code: {login_res.status_code}")

    if login_res.status_code == 302 and 'Location' in login_res.headers:
        redirect_target = login_res.headers['Location']
        redirect_url = urljoin('https://www.opendesktop.org', redirect_target)
        log_debug(f"Redirecting to {redirect_url}...")

        auth_res = session.get(redirect_url, headers=HEADERS, allow_redirects=True)
        log_debug(f"OAuth redirect final URL: {auth_res.url}, status: {auth_res.status_code}")
        auth_res.raise_for_status()
    else:
        log_http_response(login_res, "Login POST Response Error")
        if "Invalid email or password" in login_res.text or "error" in login_res.text.lower():
            print(f"Error: Authentication failed for user '{username}'. Please check your credentials.", file=sys.stderr)
        else:
            print(f"Error: Login failed with status code {login_res.status_code}.", file=sys.stderr)
        sys.exit(1)

    print("Successfully authenticated on store.kde.org!")


def get_product_edit_info(session, product_id):
    """Scrape product edit page to extract dynamic form fields and upload signature."""
    edit_url = f"{KDE_STORE_BASE}/p/{product_id}/edit"
    print(f"Fetching product edit metadata from {edit_url}...")
    res = session.get(edit_url, headers=HEADERS)
    log_debug(f"GET {edit_url} status: {res.status_code}")
    res.raise_for_status()
    html = res.text

    inputs = extract_all_inputs(html)
    log_debug(f"Extracted input names from edit page: {list(inputs.keys())}")

    all_upload_urls = re.findall(r'https://files\d*\.pling\.com/api/files/upload\?[^"\']+', html)
    log_debug(f"Found {len(all_upload_urls)} upload URLs in edit page HTML.")

    upload_url = all_upload_urls[0] if all_upload_urls else None

    signature = None
    expires = None
    if upload_url:
        parsed_url = urlparse(upload_url)
        qs = parse_qs(parsed_url.query)
        signature = qs.get('signature', [None])[0]
        expires = qs.get('expires', [None])[0]

    if not signature:
        sig_match = re.search(r'signature["\']?\s*:\s*["\']([^"\']+)["\']', html)
        if sig_match:
            signature = sig_match.group(1)
    if not expires:
        exp_match = re.search(r'expires["\']?\s*:\s*["\']([^"\']+)["\']', html)
        if exp_match:
            expires = exp_match.group(1)

    collection_id = inputs.get('collection_id') or extract_input_value(html, 'collection_id')
    if not collection_id:
        col_patterns = [
            r'data-ppload-collection-id=["\']?(\d+)["\']?',
            r'["\']?collection_id["\']?\s*[:=]\s*["\']?(\d{7,12})["\']?',
            r'["\']?collection["\']?\s*[:=]\s*["\']?(\d{7,12})["\']?',
            r'data-collection_id=["\']?(\d+)["\']?',
            r'getfilesajax\?[^"\']*collection_id=(\d+)',
            r'files/upload\?[^"\']*collection_id=(\d+)',
        ]
        for pat in col_patterns:
            m = re.search(pat, html, re.IGNORECASE)
            if m:
                collection_id = m.group(1)
                break

    owner_id = inputs.get('owner_id') or extract_input_value(html, 'owner_id')
    if not owner_id:
        owner_patterns = [
            r'owner_id["\']\s*,\s*["\']?(\d+)["\']?',
            r'data-owner_id=["\']?(\d+)["\']?',
            r'owner_id[=\s:]+["\']?(\d+)["\']?',
            r'member/(\d+)',
        ]
        for pat in owner_patterns:
            m = re.search(pat, html, re.IGNORECASE)
            if m:
                owner_id = m.group(1)
                break
    if not owner_id:
        img_path = inputs.get('image_small') or inputs.get('online_picture[1]') or html
        img_match = re.search(r'00/00/(\d{2})/(\d{2})/(\d{2})/', img_path)
        if img_match:
            owner_id = str(int(img_match.group(1) + img_match.group(2) + img_match.group(3)))

    client_id = inputs.get('client_id') or extract_input_value(html, 'client_id')
    if not client_id:
        client_patterns = [
            r'var\s+client_id\s*=\s*["\']?(\d+)["\']?',
            r'data-client_id=["\']?(\d+)["\']?',
            r'client_id[=\s:]+["\']?(\d+)["\']?',
        ]
        for pat in client_patterns:
            m = re.search(pat, html, re.IGNORECASE)
            if m:
                client_id = m.group(1)
                break

    profile_id = inputs.get('profile_id') or extract_input_value(html, 'profile_id')
    if not profile_id:
        prof_patterns = [
            r'data-profile_id=["\']?(\d+)["\']?',
            r'profile_id[=\s:]+["\']?(\d+)["\']?',
        ]
        for pat in prof_patterns:
            m = re.search(pat, html, re.IGNORECASE)
            if m:
                profile_id = m.group(1)
                break

    profile_name = inputs.get('profile_name') or extract_input_value(html, 'profile_name')
    if not profile_name:
        prof_n_patterns = [
            r'data-profile_name=["\']?([^"\'<>]+)["\']?',
            r'profile_name[=\s:]+["\']?([^"\'&,\s<>]+)["\']?',
        ]
        for pat in prof_n_patterns:
            m = re.search(pat, html, re.IGNORECASE)
            if m:
                profile_name = m.group(1).replace('+', ' ').strip()
                break

    info = {
        'collection_id': collection_id or '',
        'owner_id': owner_id or '',
        'client_id': client_id or '',
        'profile_id': profile_id or '',
        'profile_name': profile_name or '',
        'project_category_id': inputs.get('project_category_id') or extract_input_value(html, 'project_category_id') or '',
        'title': inputs.get('title') or extract_input_value(html, 'title') or '',
        'source_url': inputs.get('source_url') or extract_input_value(html, 'source_url') or '',
        'license_tag_id': inputs.get('license_tag_id') or extract_input_value(html, 'license_tag_id') or '',
        'image_small': inputs.get('image_small') or extract_input_value(html, 'image_small') or '',
        'online_picture_1': inputs.get('online_picture[1]') or extract_input_value(html, 'online_picture[1]') or '',
        'upload_url': upload_url,
        'all_upload_urls': all_upload_urls,
        'signature': signature,
        'expires': expires,
        'all_inputs': inputs,
    }

    log_debug(f"Parsed edit info: collection_id={info['collection_id']}, owner_id={info['owner_id']}, "
              f"client_id={info['client_id']}, profile_id={info['profile_id']}, "
              f"profile_name={info['profile_name']}, signature={info['signature']}, expires={info['expires']}")
    return info


def get_existing_files(session, product_id, collection_id):
    """Retrieve list of active files associated with the product."""
    if not collection_id:
        log_debug("No collection_id provided for get_existing_files.")
        return []
    url = f"{KDE_STORE_BASE}/p/{product_id}/getfilesajax?collection_id={collection_id}&perpage=1000&page=1&format=json&ignore_status_code=0&status=active"
    headers = HEADERS.copy()
    headers['X-Requested-With'] = 'XMLHttpRequest'
    log_debug(f"GET existing files URL: {url}")
    res = session.get(url, headers=headers)
    log_debug(f"getfilesajax status: {res.status_code}")
    if res.status_code == 200:
        try:
            data = res.json()
            log_debug(f"getfilesajax response: {data}")
            if isinstance(data, dict) and 'files' in data:
                return data['files']
            elif isinstance(data, list):
                return data
        except Exception as e:
            log_debug(f"Failed to parse getfilesajax JSON: {e}")
    else:
        log_http_response(res, "getfilesajax Response")
    return []


def delete_file(session, product_id, file_id):
    """Delete an existing uploaded file by file_id."""
    url = f"{KDE_STORE_BASE}/p/{product_id}/deletepploadfile/"
    headers = HEADERS.copy()
    headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'
    headers['X-Requested-With'] = 'XMLHttpRequest'
    headers['Origin'] = KDE_STORE_BASE
    headers['Referer'] = f"{KDE_STORE_BASE}/p/{product_id}/edit"

    log_debug(f"POST deletepploadfile for file_id={file_id}")
    res = session.post(url, data={'file_id': file_id}, headers=headers)
    log_debug(f"deletepploadfile status: {res.status_code}")
    if res.status_code >= 400:
        log_http_response(res, "deletepploadfile Response Error")
    res.raise_for_status()
    print(f"Deleted old file ID {file_id}.")


def upload_file_to_pling(session, filepath, edit_info):
    """Upload package file binary to Pling CDN."""
    filename = os.path.basename(filepath)
    file_size = os.path.getsize(filepath)
    with open(filepath, 'rb') as f:
        file_bytes = f.read()
    file_md5 = hashlib.md5(file_bytes).hexdigest()

    upload_url = edit_info.get('upload_url')
    if not upload_url and edit_info.get('signature') and edit_info.get('expires'):
        upload_url = f"https://files07.pling.com/api/files/upload?signature={edit_info['signature']}&expires={edit_info['expires']}"

    if not upload_url:
        print("Error: Could not determine Pling upload URL/signature.", file=sys.stderr)
        sys.exit(1)

    missing_fields = [k for k in ['client_id', 'owner_id', 'collection_id'] if not edit_info.get(k)]
    if missing_fields:
        print(f"Error: Could not dynamically extract required upload fields from edit page: {', '.join(missing_fields)}.", file=sys.stderr)
        sys.exit(1)

    print(f"Uploading '{filename}' ({file_size} bytes, md5: {file_md5}) to Pling CDN...")
    log_debug(f"Upload URL: {upload_url}")
    log_debug(f"Upload parameters: client_id={edit_info['client_id']}, owner_id={edit_info['owner_id']}, collection_id={edit_info['collection_id']}")

    # CORS Pre-flight OPTIONS request
    options_headers = {
        'User-Agent': HEADERS['User-Agent'],
        'Accept': '*/*',
        'Accept-Language': HEADERS['Accept-Language'],
        'Access-Control-Request-Method': 'POST',
        'Origin': KDE_STORE_BASE,
        'Referer': f"{KDE_STORE_BASE}/",
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
    }
    try:
        opt_res = requests.options(upload_url, headers=options_headers)
        log_debug(f"OPTIONS pre-flight status: {opt_res.status_code}")
    except Exception as e:
        log_debug(f"OPTIONS pre-flight failed: {e}")

    # .plasmoid packages are plain zip archives (KPackage format).
    files = {
        'file': (filename, file_bytes, 'application/zip'),
    }
    data = {
        'client_id': edit_info['client_id'],
        'owner_id': edit_info['owner_id'],
        'format': 'json',
        'collection_id': edit_info['collection_id'],
        'method': 'post',
    }

    post_headers = {
        'User-Agent': HEADERS['User-Agent'],
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': HEADERS['Accept-Language'],
        'Origin': KDE_STORE_BASE,
        'Referer': f"{KDE_STORE_BASE}/",
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
    }

    res = requests.post(upload_url, data=data, files=files, headers=post_headers)
    log_debug(f"Pling CDN upload response status: {res.status_code}")

    if res.status_code == 403:
        log_http_response(res, "Pling CDN Upload 403 (Direct Request)")
        log_debug("Attempting Pling CDN upload via session.post...")
        res_session = session.post(upload_url, data=data, files=files, headers=post_headers.copy())
        log_debug(f"Pling CDN upload session response status: {res_session.status_code}")
        if res_session.status_code == 200:
            res = res_session
        else:
            log_http_response(res_session, "Pling CDN Upload 403 (Session Request)")

    if res.status_code >= 400:
        print(f"\nError: Pling CDN upload failed with HTTP status {res.status_code}.", file=sys.stderr)
        log_http_response(res, "Pling CDN Final Error Response")
        sys.exit(1)

    try:
        upload_json = res.json()
        log_debug(f"Pling CDN upload JSON response: {upload_json}")
    except Exception as e:
        print(f"Error: Failed to parse Pling upload JSON response. Raw text:\n{res.text}", file=sys.stderr)
        sys.exit(1)

    uploaded_id = upload_json.get('id') or upload_json.get('file_id')
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    file_info = {
        'id': uploaded_id,
        'origin_id': uploaded_id,
        'name': filename,
        'size': file_size,
        'md5sum': file_md5,
        'timestamp': now_str,
    }
    return file_info


def register_uploaded_file(session, product_id, file_info, edit_info):
    """Link uploaded Pling CDN file to KDE Store product entry."""
    url = f"{KDE_STORE_BASE}/p/{product_id}/addpploadfile/"
    headers = HEADERS.copy()
    headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'
    headers['X-Requested-With'] = 'XMLHttpRequest'
    headers['Origin'] = KDE_STORE_BASE
    headers['Referer'] = f"{KDE_STORE_BASE}/p/{product_id}/edit"

    payload = {
        'id': file_info['id'],
        'origin_id': file_info['origin_id'],
        'active': '1',
        'client_id': edit_info['client_id'],
        'owner_id': edit_info['owner_id'],
        'profile_id': edit_info['profile_id'],
        'profile_name': edit_info['profile_name'],
        'collection_id': edit_info['collection_id'],
        'collection_active': '1',
        'collection_title': edit_info['title'],
        'collection_category': f"{edit_info['project_category_id']}-published" if edit_info['project_category_id'] else "102-published",
        'collection_tags': '',
        'collection_version': '',
        'collection_content_id': product_id,
        'collection_content_page': '',
        'name': file_info['name'],
        'type': 'application/zip',
        'size': str(file_info['size']),
        'md5sum': file_info['md5sum'],
        'title': file_info['name'],
        'description': '',
        'category': '',
        'tags': '',
        'version': '',
        'ocs_compatible': '1',
        'content_id': '',
        'content_page': '',
        'downloaded_timestamp': file_info['timestamp'],
        'downloaded_count': '0',
        'downloaded_timeperiod_count': '0',
        'created_timestamp': file_info['timestamp'],
        'updated_timestamp': file_info['timestamp'],
    }

    log_debug(f"POST addpploadfile payload: {payload}")
    res = session.post(url, data=payload, headers=headers)
    log_debug(f"addpploadfile status: {res.status_code}")
    if res.status_code >= 400:
        log_http_response(res, "addpploadfile Response Error")
    res.raise_for_status()
    print("Successfully registered uploaded file on KDE Store!")


def publish_changelog(session, product_id, title, text):
    """Add or update a changelog entry for this release."""
    url = f"{KDE_STORE_BASE}/p/{product_id}/saveupdateajax/"
    headers = HEADERS.copy()
    headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'
    headers['X-Requested-With'] = 'XMLHttpRequest'
    headers['Origin'] = KDE_STORE_BASE
    headers['Referer'] = f"{KDE_STORE_BASE}/p/{product_id}/edit"

    update_id = ''
    get_updates_url = f"{KDE_STORE_BASE}/p/{product_id}/getupdatesajax/?format=json&ignore_status_code=1"
    try:
        u_res = session.get(get_updates_url, headers=headers)
        if u_res.status_code == 200:
            u_data = u_res.json()
            updates = u_data.get('updates', [])
            for u in updates:
                u_title = u.get('title', '').strip()
                if u_title == title.strip() or title.strip() in u_title:
                    update_id = u.get('project_update_id') or u.get('id', '')
                    log_debug(f"Found existing changelog entry (ID: {update_id}) for '{title}'. Updating existing entry.")
                    break
    except Exception as e:
        log_debug(f"Failed to check existing changelog entries: {e}")

    payload = {
        'title': title,
        'text': text,
        'update_id': str(update_id),
    }

    action_str = "Updating existing" if update_id else "Publishing new"
    print(f"{action_str} changelog: '{title}'...")
    log_debug(f"POST saveupdateajax payload: {payload}")
    res = session.post(url, data=payload, headers=headers)
    log_debug(f"saveupdateajax status: {res.status_code}")
    if res.status_code >= 400:
        log_http_response(res, "saveupdateajax Response Error")
    res.raise_for_status()
    print("Changelog entry updated successfully on KDE Store!")


def update_product_metadata(session, product_id, edit_info, description, version):
    """Update main product form (version, tags, links). `description` is
    passed through unchanged (see fetch_current_description) since the edit
    form requires it in the same POST that sets the version."""
    url = f"{KDE_STORE_BASE}/p/{product_id}/edit"
    headers = HEADERS.copy()
    headers['Origin'] = KDE_STORE_BASE
    headers['Referer'] = f"{KDE_STORE_BASE}/p/{product_id}/edit"

    form_data = {
        'project_id': product_id,
        'title': edit_info['title'] or 'Fancy Tasks NG',
        'project_category_id': edit_info['project_category_id'] or '102',
        'description': description,
        'version': version,
        'source_url': edit_info['source_url'],
        'is_original_or_modification': '2',  # 2 = Modification/Fork (this is a fork of the original FancyTasks)
        'license_tag_id': edit_info['license_tag_id'] or '368',
        'cc_by_info': '',
        'tagsuser[]': PRODUCT_TAGS,
        'image_small': edit_info.get('image_small', ''),
        'online_picture[1]': edit_info.get('online_picture_1', ''),
        'MAX_FILE_SIZE': '29360128',
        'link_1': '',
        'facebook_code': '',
        'twitter_code': '',
        'archive_files_download_lock': '0',
    }

    print(f"Updating product version to {version} (description left untouched)...")
    log_debug(f"POST product edit metadata form_data keys: {list(form_data.keys())}")
    res = session.post(url, data=form_data, headers=headers, allow_redirects=True)
    log_debug(f"Product edit POST status: {res.status_code}, final URL: {res.url}")
    if res.status_code >= 400:
        log_http_response(res, "Product Edit POST Response Error")
    res.raise_for_status()
    print("Product description and version updated successfully!")


def version_from_metadata(metadata_path):
    """Read KPlugin.Version from package/metadata.json."""
    if not os.path.exists(metadata_path):
        return None
    with open(metadata_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data.get('KPlugin', {}).get('Version')


def parse_args():
    parser = argparse.ArgumentParser(description="Publish release and update details on store.kde.org")
    parser.add_argument('--product-id', default=DEFAULT_PRODUCT_ID, help=f"KDE Store product ID (default: {DEFAULT_PRODUCT_ID})")
    parser.add_argument('--collection-id', help="Explicit Pling collection ID")
    parser.add_argument('--version', help="Release version (e.g. 2.1.0); defaults to package/metadata.json's KPlugin.Version")
    parser.add_argument('--file', default=DEFAULT_ASSET_NAME, help=f"Path to the .plasmoid package (default: {DEFAULT_ASSET_NAME})")
    parser.add_argument('--metadata', default=DEFAULT_METADATA_PATH, help="Path to metadata.json (default: package/metadata.json)")
    parser.add_argument('--changelog-title', help="Title of changelog update")
    parser.add_argument('--changelog-text', help="Text of changelog update (inline)")
    parser.add_argument('--changelog-file', help="Path to a file containing the changelog text (e.g. release_notes.txt)")
    parser.add_argument('--skip-file', action='store_true', help="Skip uploading package archive file")
    parser.add_argument('--dry-run', action='store_true', help="Perform checks without modifying KDE store state")
    parser.add_argument('--verbose', '-v', action='store_true', help="Enable detailed debug logging of HTTP requests/responses")
    return parser.parse_args()


def main():
    global VERBOSE
    args = parse_args()
    if args.verbose:
        VERBOSE = True

    version = args.version or version_from_metadata(args.metadata)
    if not version:
        print("Error: Could not determine version (pass --version or check --metadata path).", file=sys.stderr)
        sys.exit(1)

    archive_file = args.file

    changelog_title = args.changelog_title or f"Version {version}"
    if args.changelog_text:
        changelog_text = args.changelog_text
    elif args.changelog_file:
        with open(args.changelog_file, 'r', encoding='utf-8') as f:
            changelog_text = f.read().strip()
    else:
        print("Error: Provide --changelog-text or --changelog-file.", file=sys.stderr)
        sys.exit(1)

    if not changelog_text:
        print(f"Error: Changelog text is empty (no '## [{version}]' section found in CHANGELOG.md?).", file=sys.stderr)
        sys.exit(1)

    user = os.environ.get('KDE_STORE_USER')
    password = os.environ.get('KDE_STORE_PASSWORD')

    if not args.dry_run and (not user or not password):
        print("Error: Missing credentials.", file=sys.stderr)
        print("Please export KDE_STORE_USER and KDE_STORE_PASSWORD environment variables.", file=sys.stderr)
        sys.exit(1)

    if not args.skip_file and not os.path.exists(archive_file):
        print(f"Archive file '{archive_file}' not found.", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("=== DRY RUN MODE ===")
        print(f"Product ID: {args.product_id}")
        if args.collection_id:
            print(f"Collection ID: {args.collection_id}")
        print(f"Version: {version}")
        print(f"Archive File: {archive_file}")
        print(f"Changelog Title: {changelog_title}")
        print(f"Changelog Text:\n{changelog_text}")
        print(f"Tags: {PRODUCT_TAGS}")
        print("Dry run completed successfully. No remote changes made.")
        return

    session = AnubisSession()

    # 1. Login
    login(session, user, password)

    # 2. Get Product Edit Metadata
    edit_info = get_product_edit_info(session, args.product_id)
    env_collection_id = os.environ.get('KDE_STORE_COLLECTION_ID')
    if args.collection_id:
        edit_info['collection_id'] = args.collection_id
        log_debug(f"Using CLI specified collection_id: {args.collection_id}")
    elif env_collection_id:
        edit_info['collection_id'] = env_collection_id
        log_debug(f"Using environment KDE_STORE_COLLECTION_ID: {env_collection_id}")

    # 3. File upload & registration
    if not args.skip_file:
        existing_files = get_existing_files(session, args.product_id, edit_info.get('collection_id'))
        target_filename = os.path.basename(archive_file)

        for ef in existing_files:
            if ef.get('name') == target_filename or ef.get('title') == target_filename:
                file_id = ef.get('id')
                if file_id:
                    print(f"Found existing file '{target_filename}' (ID: {file_id}). Deleting old file...")
                    delete_file(session, args.product_id, file_id)

        file_info = upload_file_to_pling(session, archive_file, edit_info)
        register_uploaded_file(session, args.product_id, file_info, edit_info)

    # 4. Publish Changelog
    publish_changelog(session, args.product_id, changelog_title, changelog_text)

    # 5. Bump the listed version (description is read back and resubmitted untouched)
    current_description = fetch_current_description(args.product_id)
    update_product_metadata(session, args.product_id, edit_info, current_description, version)

    print("\nAll done! Publication successfully completed on store.kde.org.")


if __name__ == '__main__':
    main()
