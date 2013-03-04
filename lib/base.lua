--[[
Copyright Tomaz Muraus

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local Emitter = require('core').Emitter
local JSON = require('json')
local querystring = require('querystring')
local https = require('https')
local url = require('url')

local async = require('async')
local KeystoneClient = require('keystone_client').Client

local BaseClient = Emitter:extend()

local ENDPOINT_URL = 'https://dfw.registry.api.rackspacecloud.com/v1.0'
local AUTH_URL = 'https://identity.api.rackspacecloud.com/v2.0'

function BaseClient:initialize(username, apiKey, region, options)
  local options

  self._username = username
  self._apiKey = apiKey
  self._region = region
  self._options = options
  self._url = ENDPOINT_URL

  options = {username = username, apikey = apiKey}
  self._keystoneClient = KeystoneClient:new(AUTH_URL, options)
end

function BaseClient:_request(path, method, payload, options, callback)
  options = options and options or {}

  async.waterfall({
    function(callback)
      self._keystoneClient:tenantIdAndToken(callback)
    end,

    function(result, callback)
      local reqUrl, headers, reqOptions

      reqUrl = self._url .. '/' .. result.tenantId .. path
      headers = {
        ['X-Auth-Token'] = result.token,
        ['User-Agent'] = 'luvit-service-registry-client',
        ['Content-Type'] = 'application/json'
      }

      if payload then
        payload = JSON.stringify(payload)
        headers['Content-Length'] = #payload
      end

      qs = querystring.urlencode(qs)

      if qs then
        reqUrl = reqUrl .. '?' .. qs
      end

      self:_performRequest(reqUrl, method, headers, payload, {}, function(err, res)
        local parsed

        if err then
          callback(err)
          return
        end

        if options.expectedStatusCode and (res.statusCode ~= options.expectedStatusCode) then
          parsed = JSON.parse(res.body)
          err = {['type'] = parsed['type'], ['message'] = parsed['message'],
                 ['details'] = parsed['details'], ['txnId'] = parsed['txnId'],
                 ['code'] = parsed['code']}
        end

        callback(err, res)
      end)
    end},

    function(err, result)
      callback(err, result)
    end)
end

function BaseClient:_create(path, payload, options, callback)
  self:_request(path, 'POST', payload, options, callback)
end

function BaseClient:_performRequest(reqUrl, method, headers, payload, options, callback)
  local parsed, reqOptions, reqPath

  parsed = url.parse(reqUrl)

  reqPath = parsed.pathname

  if parsed.search then
    reqPath = reqPath .. parsed.search
  end

  reqOptions = {
    host = parsed.hostname,
    port = tonumber(parsed.port),
    path = reqPath,
    headers = headers,
    method = method
  }

  client = https.request(reqOptions, function(res)
    local data = ''

    res:on('data', function(chunk)
      data = data .. chunk
    end)

    res:on('end', function()
      res.body = data
      callback(nil, res)
    end)
  end)

  client:on('error', callback)
  client:done(payload)
end

local exports = {}
exports.BaseClient = BaseClient
return exports
