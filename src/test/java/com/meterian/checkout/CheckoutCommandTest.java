package com.meterian.checkout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;
import org.junit.jupiter.api.Test;

class CheckoutCommandTest {

    private final CheckoutCommand checkoutCommand = new CheckoutCommand();

    @Test
    void showsTheTotalAndThePayment() {
        assertEquals("Total: 18.00" + System.lineSeparator() + "Payment: accepted",
                checkoutCommand.describeCheckout(List.of("book:10.00:2", "--discount=10")));
    }

    @Test
    void showsARefusedPayment() {
        assertEquals("Total: 2000.00" + System.lineSeparator() + "Payment: refused",
                checkoutCommand.describeCheckout(List.of("laptop:2000.00:1")));
    }

    @Test
    void refusesAnEmptyCart() {
        assertThrows(IllegalArgumentException.class, () -> checkoutCommand.describeCheckout(List.of()));
    }

    @Test
    void refusesALineThatIsNotCorrect() {
        assertThrows(IllegalArgumentException.class, () -> checkoutCommand.describeCheckout(List.of("book:ten:2")));
    }

    @Test
    void refusesADiscountThatIsNotANumber() {
        assertThrows(IllegalArgumentException.class,
                () -> checkoutCommand.describeCheckout(List.of("book:10.00:2", "--discount=ten")));
    }
}
