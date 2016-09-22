_                = require 'lodash'
colors           = require 'colors'
dashdash         = require 'dashdash'
prompt           = require 'prompt'
ConfigureService = require './src'
packageJSON      = require './package.json'
debug            = require('debug')('configure-octoblu-service')

OPTIONS = [
  {
    names: ['project-name', 'p']
    type: 'string'
    env: 'PROJECT_NAME'
    help: 'Specify the name of the Project, or Service. It should be dasherized.'
  }
  {
    names: ['private']
    type: 'bool'
    env: 'PRIVATE_PROJECT'
    help: 'A flag for specifying a private project'
    default: false
  }
  {
    names: ['root-domain']
    type: 'string'
    env: 'ROOT_DOMAIN'
    help: '(optional) Specify the root domain to add the service to'
    default: 'octoblu.com'
  }
  {
    names: ['clusters']
    type: 'string'
    env: 'CLUSTERS'
    help: '(optional) Specify the clusters to add, separated by a ","'
    default: 'major,minor,hpe'
  }
  {
    names: ['quay-token']
    type: 'string'
    env: 'QUAY_TOKEN'
    help: 'Specify the quay bearer token. Muxblu will give you this.'
  }
  {
    names: ['deploy-state-uri']
    type: 'string'
    env: 'DEPLOY_STATE_URI'
    help: 'Specify the quay deploy state uri. Muxblu will give you this.'
  }
  {
    names: ['help', 'h']
    type: 'bool'
    help: 'Print this help and exit.'
  }
  {
    names: ['version', 'v']
    type: 'bool'
    help: 'Print the version and exit.'
  }
]


class Command
  constructor: ->
    process.on 'uncaughtException', @die
    @parser = dashdash.createParser { options: OPTIONS }

  printHelp: (message) =>
    console.log "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{@parser.help({includeEnv: true})}"
    console.log message
    process.exit 0

  printHelpError: (error) =>
    console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{@parser.help({includeEnv: true})}"
    console.error colors.red error
    process.exit 1

  parseOptions: =>
    options = @parser.parse process.argv
    { help, version } = options
    { root_domain } = options
    { project_name, clusters } = options
    { quay_token, deploy_state_uri } = options
    isPrivate = options.private

    @printHelp() if help

    @printHelp packageJSON.version if version

    @printHelpError 'Missing required parameter --project-name, -p, or env: PROJECT_NAME' unless project_name?
    @printHelpError 'Missing required parameter --quay-token, or env: QUAY_TOKEN' unless quay_token?
    @printHelpError 'Missing required parameter --deploy-state-uri, or env: DEPLOY_STATE_URI' unless deploy_state_uri?

    rootDomain = root_domain.replace /^\./, ''
    clustersArray = _.compact _.map clusters?.split(','), (cluster) =>
      return cluster?.trim()

    return {
      clusters: clustersArray,
      projectName: project_name,
      quayToken: quay_token,
      rootDomain: rootDomain,
      deployStateUri: deploy_state_uri,
      isPrivate,
    }

  prompt: (options, callback) =>
    prompt.start()
    options = {
      properties: {
        projectReady: {
          message: colors.cyan('Is your Project ready to be deployed?'),
          validator: /y[es]*|n[o]?/,
          warning: 'Must respond yes or no',
          default: 'yes'
        }
        projectUpdate: {
          message: colors.cyan("Is the #{options.projectName} up to date?"),
          validator: /y[es]*|n[o]?/,
          warning: 'Must respond yes or no',
          default: 'yes'
        }
        stackEnv: {
          message: colors.cyan('Is the the-stack-env-production up to date?'),
          validator: /y[es]*|n[o]?/,
          warning: 'Must respond yes or no',
          default: 'yes'
        }
        stackServices: {
          message: colors.cyan('Is the the-stack-services up to date?'),
          validator: /y[es]*|n[o]?/,
          warning: 'Must respond yes or no',
          default: 'yes'
        }
      }
    }

    prompt.get options, (error, result) =>
      exitNow = =>
        console.error ''
        console.error ''
        console.error colors.magenta 'Yeah, you need to do that...'
        console.error ''
        process.exit 1
      return exitNow() if _.isEmpty result
      return exitNow() if 'n' in result.projectReady
      return exitNow() if 'n' in result.projectUpdate
      return exitNow() if 'n' in result.stackEnv
      return exitNow() if 'n' in result.stackServices
      callback null

  run: =>
    options = @parseOptions()

    debug 'Configuring', options

    tools = [
      'majorsync',
      'minorsync',
      'hpesync',
    ]

    @prompt options, (error) =>
      return @die error if error?
      configureService = new ConfigureService options
      configureService.run (error) =>
        return @die error if error?
        console.log ""
        console.log colors.green "INSTRUCTIONS:"
        console.log 'I did some of the hard work, but you still do a few a things'
        console.log ""
        console.log colors.bold "* Commit your project", colors.gray "I changed some stuff"
        console.log colors.bold "* Make sure the-stack-services && the-stack-env-production is in-sync.", colors.gray "I changed some stuff"
        console.log ""
        console.log colors.bold "* I recommend setting up Sentry (sentry.io)"
        console.log "  - don't forget to add the SENTRY_DSN to the project env"
        console.log ""
        console.log colors.bold "* Setup the Travis builds"
        console.log ""
        console.log colors.bold "* Setup the build trigger in Quay", colors.gray "(it needs to build on git push)"
        console.log ""
        console.log colors.bold '* Make sure to update your tools'
        console.log "  - `brew update; and brew install #{tools.join(' ')}; and brew upgrade #{tools.join(' ')}`"
        console.log ""
        console.log colors.bold "* Sync etcd:"
        console.log "  - `majorsync load #{options.projectName}/env; and minorsync load #{options.projectName}/env; and hpesync load #{options.projectName}/env`"
        console.log ""
        console.log colors.bold "* Create services:"
        console.log colors.gray " in new tab"
        console.log "  - `fleetmux`"
        console.log "  - Create 2 instances when prompted"
        console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
        console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
        console.log colors.gray " in new tab"
        console.log "  - `minormux`"
        console.log "  - Create 1 instance when prompted"
        console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
        console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
        console.log colors.gray " in new tab"
        console.log "  - `hpemux` - you may need to update and install bin in muxblu"
        console.log "  - Create 2 instances when prompted"
        console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
        console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
        console.log ""
        console.log colors.bold "* Commit the-stack-env-production and the-stack-services"
        console.log ""

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
