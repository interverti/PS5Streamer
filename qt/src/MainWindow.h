#pragma once

#include <QMainWindow>
#include <QSystemTrayIcon>

class AppController;
class QLabel;
class QPushButton;
class QListWidget;
class QLineEdit;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(AppController *controller, QWidget *parent = nullptr);

protected:
    void closeEvent(QCloseEvent *event) override;

private slots:
    void onToggle();
    void refreshUI();
    void onLogAdded(const QString &line);
    void onCopyUrl();
    void onTrayActivated(QSystemTrayIcon::ActivationReason reason);

private:
    void setupTray();
    QColor statusColor(int status) const;

    AppController *m_controller = nullptr;
    QPushButton *m_toggleBtn = nullptr;
    QLabel *m_rtmpDot = nullptr;
    QLabel *m_dnsDot = nullptr;
    QLabel *m_rtmpLabel = nullptr;
    QLabel *m_dnsLabel = nullptr;
    QLabel *m_ipValue = nullptr;
    QLineEdit *m_urlEdit = nullptr;
    QPushButton *m_copyBtn = nullptr;
    QLabel *m_urlHint = nullptr;
    QListWidget *m_logList = nullptr;
    QSystemTrayIcon *m_tray = nullptr;
};
