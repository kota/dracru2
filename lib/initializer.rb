# -*- coding: utf-8 -*-
require 'rubygems'
require 'logger'
require 'active_record'
require 'sqlite3'
require 'mechanize'
require 'json'
require 'lib/core'
require 'lib/dracru2'
require 'lib/game_map'
require 'lib/build_queue'

ROOT_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..')) 
TMP_PATH = ROOT_PATH + '/tmp'
if !File.exist?(TMP_PATH) 
  Dir::mkdir TMP_PATH
end
if File::ftype(TMP_PATH) != "directory"
  puts "tmp is not a directory. Terminate."
  exit
end

$logger = Logger.new(TMP_PATH + '/dracru.log')
$logger.info "---" + Time.now.strftime("%m/%d %H:%M")
COOKIES = TMP_PATH + '/cookies'
DB = TMP_PATH + '/dracru.db'
# ActiveRecord::Base.logger = Logger.new(TMP_PATH + '/ar.log')

begin
  require 'conf/conf'
rescue LoadError
  str = "conf file not found. Terminate."
  $logger.info str
  puts str
  exit
end

SERVER rescue SERVER = 's01'
DOMAIN = "http://#{SERVER}.dragon2.bg-time.jp/"

# ディレイ設定
SLEEP = [4.0, 4.5, 5.0, 5.5, 6.0]

# URL構造
URL = {}
{ 
  :index   => "city/index.ql",
  :hero    => "hero/index.ql?heroId=",
  :ajaxmap => "ajaxmap.ql",
  :mapinfo  => "map/areabel.ql?mapId=",
  :arena   => "building24.ql?heroId=",
}.each{ |key, value| URL[key] = DOMAIN + value }

# 出兵タイプ
ACTIONS = {:hunting => '2', :gathering => '4', :searching => '7'}
