package com.example;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class AppTest {

    @Test
    void greetingContainsEnvironment() {
        assertEquals("Hello from demo-app! Environment: DEV", App.greeting("DEV"));
    }
}
