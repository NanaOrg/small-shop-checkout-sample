package com.meterian.checkout;

import java.math.BigDecimal;
import java.util.List;

public record Cart(List<CartLine> lines) {

    public Cart {
        lines = List.copyOf(lines);
    }

    public BigDecimal calculateSubtotal() {
        return lines.stream().map(CartLine::calculatePrice).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
