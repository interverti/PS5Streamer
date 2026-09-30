#include "MainWindow.h"

#include "AppController.h"

#include <QApplication>
#include <QClipboard>
#include <QCloseEvent>
#include <QColor>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMenu>
#include <QPushButton>
#include <QStyle>
#include <QVBoxLayout>
#include <QWidget>

MainWindow::MainWindow(AppController *controller, QWidget *parent)
    : QMainWindow(parent)
    , m_controller(controller)
{
    setWindowTitle(QStringLiteral("PS5 Streamer"));
    setFixedWidth(380);
    setMinimumHeight(480);

    auto *central = new QWidget(this);
    auto *root = new QVBoxLayout(central);
    root->setContentsMargins(14, 12, 14, 12);
    root->setSpacing(10);

    // Header
    auto *header = new QHBoxLayout;
    auto *title = new QLabel(QStringLiteral("PS5 Streamer"));
    QFont titleFont = title->font();
    titleFont.setPointSize(14);
    titleFont.setBold(true);
    title->setFont(titleFont);

    m_toggleBtn = new QPushButton(QStringLiteral("Start"));
    m_toggleBtn->setFixedWidth(72);
    connect(m_toggleBtn, &QPushButton::clicked, this, &MainWindow::onToggle);

    header->addWidget(title);
    header->addStretch();
    header->addWidget(m_toggleBtn);
    root->addLayout(header);

    // Services
    auto *services = new QHBoxLayout;
    m_rtmpDot = new QLabel(QStringLiteral("●"));
    m_rtmpLabel = new QLabel(QStringLiteral("RTMP :1935"));
    m_dnsDot = new QLabel(QStringLiteral("●"));
    m_dnsLabel = new QLabel(QStringLiteral("DNS :53"));
    services->addWidget(m_rtmpDot);
    services->addWidget(m_rtmpLabel);
    services->addSpacing(16);
    services->addWidget(m_dnsDot);
    services->addWidget(m_dnsLabel);
    services->addStretch();
    root->addLayout(services);

    // DNS IP
    auto *ipLabel = new QLabel(QStringLiteral("PS5 DNS"));
    QFont small = ipLabel->font();
    small.setPointSize(9);
    ipLabel->setFont(small);
    ipLabel->setStyleSheet(QStringLiteral("color: gray;"));
    m_ipValue = new QLabel;
    QFont mono = m_ipValue->font();
    mono.setFamily(QStringLiteral("monospace"));
    mono.setPointSize(12);
    m_ipValue->setFont(mono);
    m_ipValue->setTextInteractionFlags(Qt::TextSelectableByMouse);
    root->addWidget(ipLabel);
    root->addWidget(m_ipValue);

    // URL
    auto *urlTitle = new QLabel(QStringLiteral("OBS / mpv URL"));
    urlTitle->setFont(small);
    urlTitle->setStyleSheet(QStringLiteral("color: gray;"));
    root->addWidget(urlTitle);

    auto *urlRow = new QHBoxLayout;
    m_urlEdit = new QLineEdit;
    m_urlEdit->setReadOnly(true);
    m_urlEdit->setFont(mono);
    m_copyBtn = new QPushButton(QStringLiteral("Copy"));
    m_copyBtn->setEnabled(false);
    connect(m_copyBtn, &QPushButton::clicked, this, &MainWindow::onCopyUrl);
    urlRow->addWidget(m_urlEdit);
    urlRow->addWidget(m_copyBtn);
    root->addLayout(urlRow);

    m_urlHint = new QLabel(QStringLiteral("Start to get URL"));
    m_urlHint->setStyleSheet(QStringLiteral("color: gray;"));
    root->addWidget(m_urlHint);

    // Logs
    auto *logHeader = new QHBoxLayout;
    auto *logTitle = new QLabel(QStringLiteral("Log"));
    logTitle->setFont(small);
    logTitle->setStyleSheet(QStringLiteral("color: gray;"));
    auto *clearBtn = new QPushButton(QStringLiteral("Clear"));
    clearBtn->setFlat(true);
    connect(clearBtn, &QPushButton::clicked, m_controller, &AppController::clearLogs);
    logHeader->addWidget(logTitle);
    logHeader->addStretch();
    logHeader->addWidget(clearBtn);
    root->addLayout(logHeader);

    m_logList = new QListWidget;
    m_logList->setFont(mono);
    m_logList->setMinimumHeight(140);
    root->addWidget(m_logList, 1);

    auto *quitBtn = new QPushButton(QStringLiteral("Quit"));
    quitBtn->setFlat(true);
    connect(quitBtn, &QPushButton::clicked, this, [this]() {
        m_controller->stop();
        qApp->quit();
    });
    root->addWidget(quitBtn, 0, Qt::AlignRight);

    setCentralWidget(central);

    connect(m_controller, &AppController::runningChanged, this, &MainWindow::refreshUI);
    connect(m_controller, &AppController::localIPChanged, this, &MainWindow::refreshUI);
    connect(m_controller, &AppController::streamKeyChanged, this, &MainWindow::refreshUI);
    connect(m_controller, &AppController::dnsStatusChanged, this, &MainWindow::refreshUI);
    connect(m_controller, &AppController::rtmpStatusChanged, this, &MainWindow::refreshUI);
    connect(m_controller, &AppController::logAdded, this, &MainWindow::onLogAdded);
    connect(m_controller, &AppController::logsCleared, m_logList, &QListWidget::clear);

    setupTray();
    refreshUI();
}

void MainWindow::setupTray()
{
    if (!QSystemTrayIcon::isSystemTrayAvailable())
        return;

    m_tray = new QSystemTrayIcon(this);
    m_tray->setIcon(style()->standardIcon(QStyle::SP_ComputerIcon));
    m_tray->setToolTip(QStringLiteral("PS5 Streamer"));

    auto *menu = new QMenu(this);
    menu->addAction(QStringLiteral("Show"), this, &QWidget::showNormal);
    menu->addAction(QStringLiteral("Start / Stop"), this, &MainWindow::onToggle);
    menu->addSeparator();
    menu->addAction(QStringLiteral("Quit"), this, [this]() {
        m_controller->stop();
        qApp->quit();
    });
    m_tray->setContextMenu(menu);
    connect(m_tray, &QSystemTrayIcon::activated, this, &MainWindow::onTrayActivated);
    m_tray->show();
}

void MainWindow::onTrayActivated(QSystemTrayIcon::ActivationReason reason)
{
    if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
        showNormal();
        raise();
        activateWindow();
    }
}

void MainWindow::closeEvent(QCloseEvent *event)
{
    if (m_tray && m_tray->isVisible()) {
        hide();
        event->ignore();
        return;
    }
    m_controller->stop();
    QMainWindow::closeEvent(event);
}

void MainWindow::onToggle()
{
    if (m_controller->isRunning()) {
        m_controller->stop();
        refreshUI();
        return;
    }

    m_toggleBtn->setEnabled(false);
    m_toggleBtn->setText(QStringLiteral("…"));
    m_controller->start();
}

void MainWindow::onCopyUrl()
{
    const QString url = m_controller->obsURL();
    if (!url.isEmpty())
        QApplication::clipboard()->setText(url);
}

void MainWindow::onLogAdded(const QString &line)
{
    m_logList->insertItem(0, line);
    while (m_logList->count() > 200)
        delete m_logList->takeItem(m_logList->count() - 1);
}

QColor MainWindow::statusColor(int status) const
{
    switch (static_cast<ServiceStatus>(status)) {
    case ServiceStatus::Stopped:
        return QColor(QStringLiteral("#888888"));
    case ServiceStatus::Starting:
        return QColor(QStringLiteral("#E6B800"));
    case ServiceStatus::Running:
        return QColor(QStringLiteral("#2ECC71"));
    case ServiceStatus::Error:
        return QColor(QStringLiteral("#E74C3C"));
    }
    return QColor(Qt::gray);
}

void MainWindow::refreshUI()
{
    const bool running = m_controller->isRunning();
    const bool starting = m_controller->rtmpStatus() == ServiceStatus::Starting
        || m_controller->dnsStatus() == ServiceStatus::Starting;

    m_toggleBtn->setEnabled(!starting);
    m_toggleBtn->setText(starting ? QStringLiteral("…")
                                  : (running ? QStringLiteral("Stop") : QStringLiteral("Start")));
    m_toggleBtn->setStyleSheet(running
        ? QStringLiteral("QPushButton { background: #E74C3C; color: white; }")
        : QStringLiteral("QPushButton { background: #7B2CBF; color: white; }"));

    m_ipValue->setText(m_controller->localIP());

    const auto rtmp = m_controller->rtmpStatus();
    const auto dns = m_controller->dnsStatus();
    m_rtmpDot->setStyleSheet(QStringLiteral("color: %1;").arg(statusColor(int(rtmp)).name()));
    m_dnsDot->setStyleSheet(QStringLiteral("color: %1;").arg(statusColor(int(dns)).name()));
    m_rtmpLabel->setToolTip(m_controller->rtmpStatusLabel());
    m_dnsLabel->setToolTip(m_controller->dnsStatusLabel());

    const QString url = m_controller->obsURL();
    if (!url.isEmpty()) {
        m_urlEdit->setText(url);
        m_urlEdit->show();
        m_copyBtn->setEnabled(true);
        m_copyBtn->show();
        m_urlHint->hide();
    } else {
        m_urlEdit->clear();
        m_urlEdit->hide();
        m_copyBtn->setEnabled(false);
        m_copyBtn->hide();
        m_urlHint->setText(running ? QStringLiteral("Waiting for PS5…")
                                   : QStringLiteral("Start to get URL"));
        m_urlHint->show();
    }

    if (m_tray)
        m_tray->setToolTip(running ? QStringLiteral("PS5 Streamer — Running")
                                   : QStringLiteral("PS5 Streamer"));
}
