# -*- coding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'logger'
require 'json'
require 'sqlite3'
require 'active_record'
require 'lib/game_map'
require 'conf'

DOMAIN = "http://s01.dragon2.bg-time.jp/"
URL = {
  :index => "#{DOMAIN}city/index.ql"
}

class Dracru2
  FILE_PATH = File.expand_path(File.dirname(__FILE__)) 
  COOKIES = FILE_PATH + '/cookies'
  DB = FILE_PATH + '/dracru.db'

  attr_accessor :agent

  def initialize
    @logger = Logger.new(FILE_PATH + "/dracru.log")
    @logger.info "---" + Time.now.strftime("%m/%d %H:%M")
    
    @agent = Mechanize.new
    @agent.log = Logger.new(FILE_PATH + "/mech.log")
    @agent.log.level = Logger::INFO
    @agent.user_agent_alias = 'Windows IE 7'
    @agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
    login
    prepare_map_db
  end

  def prepare_map_db
    unless File.exists?(DB)
      SQLite3::Database.new(DB)
    end
    ActiveRecord::Base.establish_connection(
      :adapter => 'sqlite3',
      :database => DB
    )
    unless GameMap.table_exists?
      ActiveRecord::Base.connection.create_table(:game_maps) do |t|
        t.column :mapid, :string
        t.column :map_type, :integer
        t.column :akuma, :bool, :default => false
        t.column :x, :integer
        t.column :y, :integer
        t.column :visited_at, :timestamp, :default => '1980-1-1'
        t.column :akuma_checked_at, :timestamp, :default => '1980-1-1'
      end
      GameMap.generate_maps(@agent)
      @logger.info('Create Map DB.')
    end
  end


  def login
    unless URL[:index] == @agent.get(URL[:index]).uri.to_s
      login_page = @agent.get "http://dragon2.bg-time.jp/member/gamestart.php?server=s01"
      server_login = login_page.form_with(:action => '/dragon2/login/') do |f|
        f.loginid = USERID
        f.password = PASSWD
      end.click_button
      server_login.form_with(:action => '/index.ql').submit
      unless Regexp.compile(URL[:index]) =~ @agent.page.uri.to_s
        raise 'Login Failed'
      else
        @logger.info 'Logged in with New Session.'
      end
    else
      @logger.info 'Logged in Using Cookies.'
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end

  def raid
    select_hero = @agent.get('http://s01.dragon2.bg-time.jp/outarms.ql?from=map&m=2&mapId=53124819')
    confirm = select_hero.form_with(:action => '/outarms.ql') do |f|
      if hero_checkbutton = f.checkbox_with(:value => '1874')
        hero_checkbutton.check
      else
        raise "Hero:#{hero_id} not available."
      end
      f.radiobuttons_with(:name => 'm').each{|radio| radio.check if radio.value == 2 }
    end.submit
    result = confirm.form_with(:action => '/outarms.ql').submit
    puts result.body
  end

end
