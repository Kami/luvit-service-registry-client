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

local string = require('string')
local table = require('table')
local JSON = require('json')
local Object = require('core').Object

local BaseClient = require('./base').BaseClient
local HeartBeater = require('./heartbeater').HeartBeater

local SessionsClient = BaseClient:extend()
local ServicesClient = BaseClient:extend()
local Client = Object:extend()

function split(str, pattern)
  pattern = pattern or "[^%s]+"
  if pattern:len() == 0 then pattern = "[^%s]+" end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end

function SessionsClient:initialize(username, apiKey, region, options)
  BaseClient.initialize(self, username, apiKey, region, options)
end

function SessionsClient:createSession(heartbeatTimeout, payload, callback)
  payload = payload and payload or {}
  payload['heartbeat_timeout'] = heartbeatTimeout

  self:_create('/sessions', payload, {['expectedStatusCode'] = 201}, function(err, res)
    local splitUrl, sessionId, hb, initialToken

    if err then
      callback(err)
      return
    end

    splitUrl = split(res.headers['location'], '[^/]+')
    sessionId = splitUrl[#splitUrl]

    initialToken = JSON.parse(res.body).token

    hb = HeartBeater:new(self._username, self._apiKey, self._region,
                         self._options, sessionId, initialToken,
                         heartbeatTimeout)

    callback(nil, sessionId, res, hb)
  end)
end

function ServicesClient:initialize(username, apiKey, region, options)
  BaseClient.initialize(self, username, apiKey, region, options)
end

function ServicesClient:createService(sessionId, serviceId, payload, callback)
  payload = payload and payload or {}
  payload['id'] = serviceId
  payload['session_id'] = sessionId

  self:_create('/services', payload, {['expectedStatusCode'] = 201}, callback)
end

function Client:initialize(username, apiKey, region, options)
  self.sessions = SessionsClient:new(username, apiKey, region, options)
  self.services = ServicesClient:new(username, apiKey, region, options)
end

local exports = {}
exports.Client = Client
return exports
