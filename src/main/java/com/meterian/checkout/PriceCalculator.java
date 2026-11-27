package com.meterian.checkout;

import java.math.BigDecimal;
import java.math.RoundingMode;

public final class PriceCalculator {

    private static final int DECIMALS = 2;

    public BigDecimal calculateTotal(Cart cart, Discount discount) {
        BigDecimal subtotal = cart.calculateSubtotal();
        BigDecimal discountAmount = discount.calculateAmount(subtotal).setScale(DECIMALS, RoundingMode.DOWN);
        return subtotal.subtract(discountAmount).setScale(DECIMALS);
    }
}
