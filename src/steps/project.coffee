_      = require 'lodash'
path   = require 'path'
yaml   = require 'node-yaml'
colors = require 'colors'
debug  = require('debug')('configure-octoblu-service')

class Project
  constructor: ({ @deployStateUri, @projectName, @isPrivate }) ->
    throw new Error 'Missing projectName argument' unless @projectName?
    throw new Error 'Missing isPrivate argument' unless @isPrivate?
    throw new Error 'Missing deployStateUri argument' unless @deployStateUri?
    @PROJECT_DIR = "#{process.env.HOME}/Projects/Octoblu/#{@projectName}"
    @travisYml = path.join @PROJECT_DIR, '.travis.yml'
    @deployStateWebhook = "#{@deployStateUri}/deployments/travis-ci/com" if @isPrivate
    @deployStateWebhook = "#{@deployStateUri}/deployments/travis-ci/org" unless @isPrivate

  configure: (callback) =>
    @_updateTravis callback

  _updateTravis: (callback) =>
    yaml.read @travisYml, (error, data) =>
      return callback error if error?
      _.set data, 'notifications.webhooks', @deployStateWebhook
      console.log colors.cyan 'WRITING:', @travisYml
      yaml.write @travisYml, data, callback

module.exports = Project
