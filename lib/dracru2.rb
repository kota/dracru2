# -*- coding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'logger'
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

end
