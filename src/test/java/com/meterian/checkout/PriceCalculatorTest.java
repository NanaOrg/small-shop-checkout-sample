package com.meterian.checkout;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;

class PriceCalculatorTest {

    private final PriceCalculator priceCalculator = new PriceCalculator();

    @Test
    void addsThePricesOfAllLines() {
        Cart cart = new Cart(List.of(
                new CartLine("book", new BigDecimal("10.00"), 2),
                new CartLine("pen", new BigDecimal("1.50"), 1)));

        assertEquals(new BigDecimal("21.50"), priceCalculator.calculateTotal(cart, Discount.NONE));
    }

    @Test
    void subtractsTheDiscount() {
        Cart cart = new Cart(List.of(new CartLine("book", new BigDecimal("20.00"), 1)));

        assertEquals(new BigDecimal("18.00"), priceCalculator.calculateTotal(cart, new Discount(10)));
    }
}
