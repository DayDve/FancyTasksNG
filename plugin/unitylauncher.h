/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVariant>
#include <QHash>
#include <QUrl>
#include <QQmlEngine>

class UnityLauncherBackend : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.Unity.LauncherEntry")
public:
    static UnityLauncherBackend* instance();

    int count(const QString &storageId) const;
    bool countVisible(const QString &storageId) const;
    int progress(const QString &storageId) const;
    bool progressVisible(const QString &storageId) const;
    bool urgent(const QString &storageId) const;

Q_SIGNALS:
    void countChanged(const QString &storageId, int count);
    void countVisibleChanged(const QString &storageId, bool countVisible);
    void progressChanged(const QString &storageId, int progress);
    void progressVisibleChanged(const QString &storageId, bool progressVisible);
    void urgentChanged(const QString &storageId, bool urgent);

private Q_SLOTS:
    void update(const QString &uri, const QMap<QString, QVariant> &properties);

private:
    explicit UnityLauncherBackend(QObject *parent = nullptr);
    ~UnityLauncherBackend();

    bool parseStorageId(const QString &uri, QString &storageId);

    struct Entry {
        int count = 0;
        bool countVisible = false;
        int progress = 0;
        bool progressVisible = false;
        bool urgent = false;
    };

    QHash<QString, Entry> m_launchers;
    QHash<QString, QString> m_launcherUrlToStorageId;
};

class SmartLauncherItem : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(SmartLauncherItem)

    Q_PROPERTY(QUrl launcherUrl READ launcherUrl WRITE setLauncherUrl NOTIFY launcherUrlChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool countVisible READ countVisible NOTIFY countVisibleChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(bool progressVisible READ progressVisible NOTIFY progressVisibleChanged)
    Q_PROPERTY(bool urgent READ urgent NOTIFY urgentChanged)

public:
    explicit SmartLauncherItem(QObject *parent = nullptr);
    ~SmartLauncherItem() override = default;

    QUrl launcherUrl() const;
    void setLauncherUrl(const QUrl &launcherUrl);

    int count() const;
    bool countVisible() const;
    int progress() const;
    bool progressVisible() const;
    bool urgent() const;

Q_SIGNALS:
    void launcherUrlChanged(const QUrl &launcherUrl);
    void countChanged(int count);
    void countVisibleChanged(bool countVisible);
    void progressChanged(int progress);
    void progressVisibleChanged(bool progressVisible);
    void urgentChanged(bool urgent);

private Q_SLOTS:
    void onBackendCountChanged(const QString &storageId, int count);
    void onBackendCountVisibleChanged(const QString &storageId, bool countVisible);
    void onBackendProgressChanged(const QString &storageId, int progress);
    void onBackendProgressVisibleChanged(const QString &storageId, bool progressVisible);
    void onBackendUrgentChanged(const QString &storageId, bool urgent);

private:
    QUrl m_launcherUrl;
    QString m_storageId;
};
