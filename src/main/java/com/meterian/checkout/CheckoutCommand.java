package com.meterian.checkout;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

public final class CheckoutCommand {

    static final String USAGE = "Usage: <product>:<unit price>:<quantity>... [--discount=<percent>]";

    private static final String DISCOUNT_OPTION = "--discount=";
    private static final int PARTS_OF_A_LINE = 3;

    private final PriceCalculator priceCalculator = new PriceCalculator();
    private final PaymentRule paymentRule = new PaymentRule();

    public static void main(String[] arguments) {
        try {
            System.out.println(new CheckoutCommand().describeCheckout(List.of(arguments)));
        } catch (IllegalArgumentException exception) {
            System.err.println(exception.getMessage());
            System.err.println(USAGE);
            System.exit(1);
        }
    }

    String describeCheckout(List<String> arguments) {
        BigDecimal total = priceCalculator.calculateTotal(readCart(arguments), readDiscount(arguments));
        String payment = paymentRule.accepts(total) ? "accepted" : "refused";
        return "Total: " + total + System.lineSeparator() + "Payment: " + payment;
    }

    private static Cart readCart(List<String> arguments) {
        List<CartLine> lines = new ArrayList<>();
        for (String argument : arguments) {
            if (!argument.startsWith(DISCOUNT_OPTION)) {
                lines.add(readLine(argument));
            }
        }
        if (lines.isEmpty()) {
            throw new IllegalArgumentException("The cart is empty.");
        }
        return new Cart(lines);
    }

    private static CartLine readLine(String argument) {
        String[] parts = argument.split(":");
        if (parts.length != PARTS_OF_A_LINE) {
            throw new IllegalArgumentException("The cart line is not correct: " + argument);
        }
        try {
            return new CartLine(parts[0], new BigDecimal(parts[1]), Integer.parseInt(parts[2]));
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("The cart line is not correct: " + argument, exception);
        }
    }

    private static Discount readDiscount(List<String> arguments) {
        return arguments.stream()
                .filter(argument -> argument.startsWith(DISCOUNT_OPTION))
                .map(argument -> argument.substring(DISCOUNT_OPTION.length()))
                .map(CheckoutCommand::parseDiscount)
                .findFirst()
                .orElse(Discount.NONE);
    }

    private static Discount parseDiscount(String percent) {
        try {
            return new Discount(Integer.parseInt(percent));
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("The discount is not a whole number: " + percent, exception);
        }
    }
}
