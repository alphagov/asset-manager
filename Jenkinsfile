#!/usr/bin/env groovy

library("govuk")

node ('mongodb-3.2') {
  govuk.buildProject(
    beforeTest: {
      govuk.setEnvar('TEST_COVERAGE', 'true')
      govuk.setEnvar('JWT_AUTH_SECRET', 'secret')
    },
    sassLint: false,
    publishingE2ETests: true,
    rubyLintDirs: "",
    brakeman: true,
    afterTest: {
      govuk.setEnvar('AWS_S3_BUCKET_NAME', 'asset-precompilation-test')
    }
  )
}
