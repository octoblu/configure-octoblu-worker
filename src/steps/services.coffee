_            = require 'lodash'
fs           = require 'fs-extra'
path         = require 'path'
glob         = require 'glob'
eco          = require 'eco'
async        = require 'async'
colors       = require 'colors'
debug        = require('debug')('configure-octoblu-service')

class Services
  constructor: ({ @projectName }) ->
    throw new Error 'Missing projectName argument' unless @projectName
    @baseDir = "#{process.env.HOME}/Projects/Octoblu/the-stack-services/services.d"
    @confDir = path.join(__dirname, '..', '..', 'node_modules', 'deployinate-configurator')

  configure: (callback) =>
    fs.ensureDir path.join(@baseDir, @projectName), (error) =>
      return callback error if error?
      @_createTemplates callback

  _forEachTemplate: (callback) =>
    templateNames = [
      '-sidekick@.service'
      '@.service'
    ]
    names = templateNames.join(',')
    filePath = path.join @confDir, "templates-worker/**/{#{names}}.eco"
    glob filePath, callback

  _createTemplates: (callback) =>
    @_forEachTemplate (error, files) =>
      return callback error if error?
      async.each files, @_processFile, callback

  _processFile: (file, callback) =>
    outputFilename = path.basename file.replace('.eco', '')
    template = fs.readFileSync file, "utf-8"
    filename = "octoblu-#{@projectName}#{outputFilename}"

    contents = eco.render template, {
      project_name: @projectName
      namespace: 'octoblu'
    }

    filePath = path.join @baseDir, @projectName, filename
    console.log colors.cyan 'WRITING:', filePath
    fs.writeFile filePath, contents, callback

module.exports = Services
