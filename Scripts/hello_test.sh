#!/bin/bash
. shunit2

testHelloWorld() {
  assertEquals "Hello, World!" "Hello, World!"
}

# Run the tests
. shunit2