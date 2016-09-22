_       = require 'lodash'
request = require 'request'
async   = require 'async'
debug   = require('debug')('configure-octoblu-service')

QUAY_BASE_URL='https://quay.io/api/v1'

class Quay
  constructor: ({ @deployStateUri, @projectName, @isPrivate, @quayToken }) ->
    throw new Error 'Missing projectName argument' unless @projectName?
    throw new Error 'Missing deployStateUri argument' unless @deployStateUri?
    throw new Error 'Missing quayToken argument' unless @quayToken?

  configure: (callback) =>
    debug 'setting up quay'
    @_createRepository (error) =>
      return callback error if error?
      @_createNotification callback

  _getNotifications: (callback) =>
    debug 'getting notifications'
    options =
      method: 'GET'
      uri: "/repository/octoblu/#{@projectName}/notification/"
      json: true

    @_request options, (error, body) =>
      return callback error if error?
      debug 'got notifications', body.notifications
      callback null, body.notifications

  _deleteNotification: ({ uuid }, callback) =>
    debug 'delete notification', { uuid }
    options =
      method: 'DELETE'
      uri: "/repository/octoblu/#{@projectName}/notification/#{uuid}"
      json: true

    @_request options, callback

  _clearNotifications: (callback) =>
    @_getNotifications (error, notifications) =>
      return callback error if error?
      async.each notifications, @_deleteNotification, callback

  _createNotification: (callback) =>
    options =
      method: 'POST'
      uri: "/repository/octoblu/#{@projectName}/notification/"
      json:
        eventConfig: {}
        title: "Deploy State"
        config:
          url: "#{@deployStateUri}/deployments/quay.io"
        event: "repo_push"
        method: "webhook"

    debug 'create notification in quay', options
    @_clearNotifications (error) =>
      return callback error if error?
      @_request options, (error, body) =>
        return callback error if error?
        callback null

  _repositoryExists: (callback) =>
    options =
      method: 'GET'
      uri: "/repository/octoblu/#{@projectName}"
      json: true

    @_request options, (error, body, statusCode) =>
      return callback error if error?
      exists = statusCode != 404
      debug 'repo exists', exists
      callback null, exists

  _createRepository: (callback) =>
    visibility = 'public'
    visibility = 'private' if @isPrivate
    options =
      method: 'POST'
      uri: '/repository'
      json:
        namespace: 'octoblu'
        visibility: visibility
        repository: @projectName
        description: "Octoblu Service #{@projectName}"

    @_repositoryExists (error, exists) =>
      return callback error if error?
      return callback null if exists
      debug 'create repository in quay', options
      @_request options, (error, body) =>
        return callback error if error?
        callback null

  _request: ({ method, uri, json }, callback) =>
    options = {
      method,
      uri,
      baseUrl: QUAY_BASE_URL
      headers:
        Authorization: "Bearer #{@quayToken}"
      followAllRedirects: true
      json
    }
    request options, (error, response, body) =>
      return callback error, null, response.statusCode if error?
      return callback body, null, response.statusCode if response.statusCode > 499
      callback null, body, response.statusCode

module.exports = Quay
