do_package_checks()

if (Sys.getenv("DEV_VERSIONS") != "") {
  get_stage("install") %>%
    add_step(step_install_github(c("r-lib/rlang", "r-lib/cli", "r-lib/crayon", "r-lib/pillar", "r-lib/pkgconfig")))
}

if (Sys.getenv("BUILD_PKGDOWN") != "" && ci()$get_branch() == "master") {
  # pkgdown documentation can be built optionally. Other example criteria:
  # - `inherits(ci(), "TravisCI")`: Only for Travis CI
  # - `ci()$is_tag()`: Only for tags, not for branches
  # - `Sys.getenv("BUILD_PKGDOWN") != ""`: If the env var "BUILD_PKGDOWN" is set
  # - `Sys.getenv("TRAVIS_EVENT_TYPE") == "cron"`: Only for Travis cron jobs
  get_stage("install") %>%
    add_step(step_install_github("tidyverse/tidytemplate"))

  get_stage("before_deploy") %>%
    add_step(step_setup_ssh())

  get_stage("deploy") %>%
    add_step(step_setup_push_deploy(path = "docs", branch = "gh-pages")) %>%
    add_step(step_build_pkgdown()) %>%
    add_step(step_do_push_deploy(path = "docs"))
}
