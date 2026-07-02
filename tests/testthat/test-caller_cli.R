test_that("multiplication works", {
  caller_cli <- create_caller_cli_env()

  f <- function() {
    print("In f")
    caller_cli$cli_alert_info("In f")
  }

  g <- function() {
    print("In g")
    f()
  }

  h <- function() {
    print("In h")
    g()
  }

  h()
})
