#!/usr/bin/env groovy

node ('mongodb-2.4') {
  def govuk = load '/var/lib/jenkins/groovy_scripts/govuk_jenkinslib.groovy'
  govuk.buildProject(
    beforeTest: {
      govuk.setEnvar('TEST_COVERAGE', 'true')
    },
    sassLint: false,
    publishingE2ETests: true,
    afterTest: {
      govuk.setEnvar('AWS_S3_BUCKET_NAME', 'asset-precompilation-test')
    }
  )
}
