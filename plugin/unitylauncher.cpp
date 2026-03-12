/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "unitylauncher.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>
#include <QQmlExtensionPlugin>
#include <limits>
#include <cmath>

UnityLauncherBackend* UnityLauncherBackend::instance()
{
    static UnityLauncherBackend* s_instance = new UnityLauncherBackend();
    return s_instance;
}

UnityLauncherBackend::UnityLauncherBackend(QObject *parent)
    : QObject(parent)
{
    auto sessionBus = QDBusConnection::sessionBus();
    
    // Register the Unity service "politely".
    // If it fails (name taken by another task manager), we just log it and move on.
    // Applications will still emit signals that we can hear.
    if (!sessionBus.registerService(QStringLiteral("com.canonical.Unity"))) {
        qDebug() << "FancyTasks: com.canonical.Unity service already owned by another process.";
    }

    // Register object to handle potential calls and signal catching
    sessionBus.registerObject(QStringLiteral("/Unity"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);

    // Connect to the Update signal. IMPORTANT: This works even if we don't own the "com.canonical.Unity" name,
    // as long as SOMEONE is sending signals to the bus.
    bool connected = sessionBus.connect(QString(), // Any service
                                        QString(), // Any path
                                        QStringLiteral("com.canonical.Unity.LauncherEntry"),
                                        QStringLiteral("Update"),
                                        this,
                                        SLOT(update(QString, QMap<QString, QVariant>)));
    if (!connected) {
        qWarning() << "FancyTasks: Failed to connect to Unity.LauncherEntry Update signals";
    }
}

UnityLauncherBackend::~UnityLauncherBackend() = default;

bool UnityLauncherBackend::parseStorageId(const QString &uri, QString &storageId)
{
    auto foundStorageId = m_launcherUrlToStorageId.constFind(uri);
    if (foundStorageId != m_launcherUrlToStorageId.constEnd()) {
        storageId = *foundStorageId;
        return true;
    }

    QString normalizedUri = uri;
    // Common prefixes in Unity API
    if (normalizedUri.startsWith(QLatin1String("application://"))) {
        normalizedUri = normalizedUri.mid(14);
    } else if (normalizedUri.startsWith(QLatin1String("applications:"))) {
        normalizedUri = normalizedUri.mid(13);
    }

    // If it's a full path, take only the filename
    int slashIdx = normalizedUri.lastIndexOf(QLatin1Char('/'));
    if (slashIdx != -1) {
        normalizedUri = normalizedUri.mid(slashIdx + 1);
    }
    
    // Ensure it ends with .desktop for internal matching
    if (!normalizedUri.endsWith(QLatin1String(".desktop"))) {
        // Many apps send just "kmail2" instead of "org.kde.kmail2.desktop"
        // We'll trust the base name for now.
    }

    storageId = normalizedUri;
    m_launcherUrlToStorageId.insert(uri, storageId);
    return true;
}

void UnityLauncherBackend::update(const QString &uri, const QMap<QString, QVariant> &properties)
{
    QString storageId;
    if (!parseStorageId(uri, storageId) || storageId.isEmpty()) {
        return;
    }

    auto foundEntry = m_launchers.find(storageId);
    if (foundEntry == m_launchers.end()) {
        Entry entry;
        foundEntry = m_launchers.insert(storageId, entry);
    }

    auto propertiesEnd = properties.constEnd();

    // Update count
    auto foundCount = properties.constFind(QStringLiteral("count"));
    if (foundCount != propertiesEnd) {
        qint64 newCount = foundCount->toLongLong();
        if (newCount < std::numeric_limits<int>::max()) {
            int saneCount = static_cast<int>(newCount);
            if (saneCount != foundEntry->count) {
                foundEntry->count = saneCount;
                Q_EMIT countChanged(storageId, saneCount);
            }
        }
    }

    // Update count visibility
    auto foundCountVisible = properties.constFind(QStringLiteral("count-visible"));
    if (foundCountVisible != propertiesEnd) {
        bool countVisible = foundCountVisible->toBool();
        if (countVisible != foundEntry->countVisible) {
            foundEntry->countVisible = countVisible;
            Q_EMIT countVisibleChanged(storageId, countVisible);
        }
    }

    // Update progress
    auto foundProgress = properties.constFind(QStringLiteral("progress"));
    if (foundProgress != propertiesEnd) {
        double progressValue = foundProgress->toDouble();
        if (!std::isfinite(progressValue)) {
            progressValue = 0.0;
        }
        int newProgress = std::round(progressValue * 100);
        if (newProgress != foundEntry->progress) {
            foundEntry->progress = newProgress;
            Q_EMIT progressChanged(storageId, newProgress);
        }
    }

    // Update progress visibility
    auto foundProgressVisible = properties.constFind(QStringLiteral("progress-visible"));
    if (foundProgressVisible != propertiesEnd) {
        bool progressVisible = foundProgressVisible->toBool();
        if (progressVisible != foundEntry->progressVisible) {
            foundEntry->progressVisible = progressVisible;
            Q_EMIT progressVisibleChanged(storageId, progressVisible);
        }
    }

    // Update urgent
    auto foundUrgent = properties.constFind(QStringLiteral("urgent"));
    if (foundUrgent != propertiesEnd) {
        bool urgentVal = foundUrgent->toBool();
        if (urgentVal != foundEntry->urgent) {
            foundEntry->urgent = urgentVal;
            Q_EMIT urgentChanged(storageId, urgentVal);
        }
    }
}

int UnityLauncherBackend::count(const QString &storageId) const { return m_launchers.value(storageId).count; }
bool UnityLauncherBackend::countVisible(const QString &storageId) const { return m_launchers.value(storageId).countVisible; }
int UnityLauncherBackend::progress(const QString &storageId) const { return m_launchers.value(storageId).progress; }
bool UnityLauncherBackend::progressVisible(const QString &storageId) const { return m_launchers.value(storageId).progressVisible; }
bool UnityLauncherBackend::urgent(const QString &storageId) const { return m_launchers.value(storageId).urgent; }

// --- SmartLauncherItem ---

SmartLauncherItem::SmartLauncherItem(QObject *parent)
    : QObject(parent)
{
    auto be = UnityLauncherBackend::instance();
    connect(be, &UnityLauncherBackend::countChanged, this, &SmartLauncherItem::onBackendCountChanged);
    connect(be, &UnityLauncherBackend::countVisibleChanged, this, &SmartLauncherItem::onBackendCountVisibleChanged);
    connect(be, &UnityLauncherBackend::progressChanged, this, &SmartLauncherItem::onBackendProgressChanged);
    connect(be, &UnityLauncherBackend::progressVisibleChanged, this, &SmartLauncherItem::onBackendProgressVisibleChanged);
    connect(be, &UnityLauncherBackend::urgentChanged, this, &SmartLauncherItem::onBackendUrgentChanged);
}

QUrl SmartLauncherItem::launcherUrl() const
{
    return m_launcherUrl;
}

void SmartLauncherItem::setLauncherUrl(const QUrl &launcherUrl)
{
    if (m_launcherUrl == launcherUrl) {
        return;
    }
    m_launcherUrl = launcherUrl;

    QString normalizedUri = launcherUrl.toString();
    if (normalizedUri.startsWith(QLatin1String("file://"))) {
        int slashIdx = normalizedUri.lastIndexOf(QLatin1Char('/'));
        if (slashIdx != -1) {
            normalizedUri = normalizedUri.mid(slashIdx + 1);
        }
    } else if (normalizedUri.startsWith(QLatin1String("applications:"))) {
        normalizedUri = normalizedUri.mid(13);
    } else if (normalizedUri.startsWith(QLatin1String("preferred://"))) {
        int slashIdx = normalizedUri.lastIndexOf(QLatin1Char('/'));
        if (slashIdx != -1) {
            normalizedUri = normalizedUri.mid(slashIdx + 1);
        }
    }

    m_storageId = normalizedUri;

    Q_EMIT launcherUrlChanged(m_launcherUrl);
    
    Q_EMIT countChanged(count());
    Q_EMIT countVisibleChanged(countVisible());
    Q_EMIT progressChanged(progress());
    Q_EMIT progressVisibleChanged(progressVisible());
    Q_EMIT urgentChanged(urgent());
}

int SmartLauncherItem::count() const { if (m_storageId.isEmpty()) return 0; return UnityLauncherBackend::instance()->count(m_storageId); }
bool SmartLauncherItem::countVisible() const { if (m_storageId.isEmpty()) return false; return UnityLauncherBackend::instance()->countVisible(m_storageId); }
int SmartLauncherItem::progress() const { if (m_storageId.isEmpty()) return 0; return UnityLauncherBackend::instance()->progress(m_storageId); }
bool SmartLauncherItem::progressVisible() const { if (m_storageId.isEmpty()) return false; return UnityLauncherBackend::instance()->progressVisible(m_storageId); }
bool SmartLauncherItem::urgent() const { if (m_storageId.isEmpty()) return false; return UnityLauncherBackend::instance()->urgent(m_storageId); }

void SmartLauncherItem::onBackendCountChanged(const QString &storageId, int count) {
    if (!m_storageId.isEmpty() && storageId.contains(m_storageId)) Q_EMIT countChanged(count);
}
void SmartLauncherItem::onBackendCountVisibleChanged(const QString &storageId, bool countVisible) {
    if (!m_storageId.isEmpty() && storageId.contains(m_storageId)) Q_EMIT countVisibleChanged(countVisible);
}
void SmartLauncherItem::onBackendProgressChanged(const QString &storageId, int progress) {
    if (!m_storageId.isEmpty() && storageId.contains(m_storageId)) Q_EMIT progressChanged(progress);
}
void SmartLauncherItem::onBackendProgressVisibleChanged(const QString &storageId, bool progressVisible) {
    if (!m_storageId.isEmpty() && storageId.contains(m_storageId)) Q_EMIT progressVisibleChanged(progressVisible);
}
void SmartLauncherItem::onBackendUrgentChanged(const QString &storageId, bool urgent) {
    if (!m_storageId.isEmpty() && storageId.contains(m_storageId)) Q_EMIT urgentChanged(urgent);
}

class UnityPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")
public:
    void registerTypes(const char *uri) override {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("io.github.daydve.fancytasksng.unity"));
        qmlRegisterType<SmartLauncherItem>(uri, 1, 0, "SmartLauncherItem");
    }
};

#include "unitylauncher.moc"
#include "moc_unitylauncher.cpp"
