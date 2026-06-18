def fmt_currency(val, unit="K"):
    if unit == "K":
        return f"${val / 1_000:,.1f}K"
    if unit == "M":
        return f"${val / 1_000_000:,.2f}M"
    return f"${val:,.0f}"


def fmt_pct(val):
    return f"{val * 100:.1f}%"


def fmt_bps(val):
    return f"{val * 10000:+.0f}bps"


def fmt_yoy(val):
    return f"{val * 100:+.1f}%"


def badge_color(val, bps=False):
    threshold = 0.0015 if bps else 0.0
    if val > threshold:
        return "#16a34a"   # green — works on light backgrounds
    elif val < -threshold:
        return "#dc2626"   # red
    else:
        return "#d97706"   # amber
