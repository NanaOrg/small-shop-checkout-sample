package com.meterian.checkout;

import java.math.BigDecimal;

/** A discount in percent. The amount is exact, without rounding. */
public record Discount(int percent) {

    public static final Discount NONE = new Discount(0);

    public Discount {
        if (percent < 0 || percent > 100) {
            throw new IllegalArgumentException("The discount must be from 0 to 100 percent.");
        }
    }

    public BigDecimal calculateAmount(BigDecimal price) {
        return price.multiply(BigDecimal.valueOf(percent)).movePointLeft(2);
    }
}
