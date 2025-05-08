node('linux')
{
  stage ('Poll') {
    checkout([
      $class: 'GitSCM',
      branches: [[name: '*/main']],
      doGenerateSubmoduleConfigurations: false,
      extensions: [],
      userRemoteConfigs: [[url: 'https://github.com/zopencommunity/libarchiveport.git']]])
  }
  stage('Build') {
    build job: 'Port-Pipeline', parameters: [string(name: 'PORT_GITHUB_REPO', value: 'https://github.com/zopencommunity/libarchiveport.git'), string(name: 'PORT_DESCRIPTION', value: 'The libarchive project develops a portable, efficient C library that can read and write streaming archives in a variety of formats. It also includes implementations of the common tar, cpio, and zcat command-line tools that use the libarchive library.' ), string(name: 'BUILD_LINE', value: 'STABLE') ]
  }
}
