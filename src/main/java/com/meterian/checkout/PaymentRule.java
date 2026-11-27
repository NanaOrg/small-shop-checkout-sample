package com.meterian.checkout;

import java.math.BigDecimal;

public final class PaymentRule {

    private static final BigDecimal HIGHEST_ACCEPTED_AMOUNT = new BigDecimal("1000.00");

    public boolean accepts(BigDecimal amount) {
        return amount.signum() > 0 && amount.compareTo(HIGHEST_ACCEPTED_AMOUNT) <= 0;
    }
}
