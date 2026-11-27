package com.meterian.checkout;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class PaymentRuleTest {

    private final PaymentRule paymentRule = new PaymentRule();

    @Test
    void acceptsTheHighestAmount() {
        assertTrue(paymentRule.accepts(new BigDecimal("1000.00")));
    }

    @Test
    void refusesAHigherAmount() {
        assertFalse(paymentRule.accepts(new BigDecimal("1000.01")));
    }

    @Test
    void refusesZero() {
        assertFalse(paymentRule.accepts(new BigDecimal("0.00")));
    }
}
