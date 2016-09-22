_            = require 'lodash'
async        = require 'async'
fs           = require 'fs-extra'
path         = require 'path'
colors       = require 'colors'
debug        = require('debug')('configure-octoblu-service')

class Etcd
  constructor: ({ @projectName, @rootDomain, @clusters }) ->
    throw new Error 'Missing projectName argument' unless @projectName?
    throw new Error 'Missing clusters argument' unless @clusters?
    throw new Error 'Missing rootDomain argument' unless @rootDomain?
    { @version } = require "#{process.env.HOME}/Projects/Octoblu/#{@projectName}/package.json"
    @ENV_DIR = "#{process.env.HOME}/Projects/Octoblu/the-stack-env-production"

  configure: (callback) =>
    async.eachSeries @clusters, @_createEnv, callback

  _createEnv: (cluster, callback) =>
    debug 'creating env', { cluster }
    clusterConfigPath = path.join @ENV_DIR, cluster
    fs.stat clusterConfigPath, (error, stats) =>
      return callback error if error?
      return callback new Error("No configuration for #{cluster}") unless stats.isDirectory()
      projectPath = path.join clusterConfigPath, 'etcd', 'octoblu', @projectName
      debug 'projectPath', projectPath
      fs.ensureDir path.join(projectPath, 'env'), (error) =>
        return callback error if error?
        @_writeFiles projectPath, callback

  _writeFiles: (projectPath, callback) =>
    @_writeDebug projectPath, callback

  _writeDebug: (projectPath, callback) =>
    debugPath = path.join projectPath, 'env', 'DEBUG'
    console.log colors.cyan 'WRITING:', debugPath
    fs.writeFile debugPath, 'nothing', callback

module.exports = Etcd
