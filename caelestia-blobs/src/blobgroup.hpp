#pragma once

#include <qcolor.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlengine.h>

class BlobShape;
class BlobInvertedRect;

class BlobGroup : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    // 顶 → 底渐变;不设(或 colorBottom==color)时退化为单色
    Q_PROPERTY(QColor colorBottom READ colorBottom WRITE setColorBottom NOTIFY colorBottomChanged)
    Q_PROPERTY(qreal gradientTop READ gradientTop WRITE setGradientTop NOTIFY gradientTopChanged)
    Q_PROPERTY(qreal gradientBottom READ gradientBottom WRITE setGradientBottom NOTIFY gradientBottomChanged)

public:
    explicit BlobGroup(QObject* parent = nullptr);
    ~BlobGroup() override;

    qreal smoothing() const { return m_smoothing; }

    void setSmoothing(qreal s);

    QColor color() const { return m_color; }

    void setColor(const QColor& c);

    QColor colorBottom() const { return m_colorBottom; }
    void setColorBottom(const QColor& c);

    qreal gradientTop() const { return m_gradientTop; }
    void setGradientTop(qreal v);

    qreal gradientBottom() const { return m_gradientBottom; }
    void setGradientBottom(qreal v);

    void addShape(BlobShape* shape);
    void removeShape(BlobShape* shape);

    void setInvertedRect(BlobInvertedRect* rect);
    void clearInvertedRect(BlobInvertedRect* rect);

    const QList<BlobShape*>& shapes() const { return m_shapes; }

    BlobInvertedRect* invertedRect() const { return m_invertedRect; }

    void markDirty();
    void markShapeDirty(BlobShape* source);
    void ensurePhysicsUpdated();

signals:
    void smoothingChanged();
    void colorChanged();
    void colorBottomChanged();
    void gradientTopChanged();
    void gradientBottomChanged();

private:
    qreal m_smoothing = 32.0;
    QColor m_color{ 0x44, 0x88, 0xff };
    QColor m_colorBottom{ 0x44, 0x88, 0xff };  // 默认 = color,退化为无渐变
    qreal m_gradientTop = 0;
    qreal m_gradientBottom = 0;
    QList<BlobShape*> m_shapes;
    BlobInvertedRect* m_invertedRect = nullptr;
    bool m_physicsUpdated = false;
};
