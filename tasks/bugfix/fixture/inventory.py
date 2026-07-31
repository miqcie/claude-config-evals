def apply_discount(prices, code):
    """Apply a discount code to a price list. Codes: SAVE10 (10%), HALF (50%)."""
    rates = {"SAVE10": 0.10, "HALF": 0.50}
    rate = rates[code]  # bug: unknown codes crash instead of applying no discount
    return [round(p * (1 - rate), 2) for p in prices]


def total(prices):
    return round(sum(prices), 2)
