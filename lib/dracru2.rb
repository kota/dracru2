# -*- coding: utf-8 -*-
class Dracru2
  include Core

  attr_accessor :agent

  def initialize
    @agent = Mechanize.new
    @agent.log = Logger.new(TMP_PATH + "/mech.log")
    @agent.log.level = Logger::INFO
    @agent.user_agent_alias = 'Windows IE 7'
    @agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
    login
    @main_city = cities[0] # 主城
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
        t.column :map_type, :string
        t.column :akuma, :bool, :default => false
        t.column :x, :integer
        t.column :y, :integer
        t.column :visited_at, :timestamp, :default => '1980-1-1'
        t.column :akuma_checked_at, :timestamp, :default => '1980-1-1'
        t.timestamps
      end
      GameMap.generate_maps(@agent, @main_city)
      $logger.info('Create Map DB.')
    end
  end


  def login
    unless URL[:index] == @agent.get(URL[:index]).uri.to_s
      login_page = @agent.get "http://dragon2.bg-time.jp/member/gamestart.php?server=#{SERVER}"
      delay
      server_login = login_page.form_with(:action => '/dragon2/login/') do |f|
        f.loginid = USERID
        f.password = PASSWD
      end.click_button
      server_login.form_with(:action => '/index.ql').submit
      unless Regexp.compile(URL[:index]) =~ @agent.page.uri.to_s
        raise 'Login Failed'
      else
        $logger.info 'Logged in with New Session.'
      end
    else
      $logger.info 'Logged in Using Cookies.'
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end

  def raid_if_possible
    HERO_IDS.each do |hero_id|
      levelup(hero_id)
      #TODO 条件判定いろいろ
      if map = GameMap.get_available_map(@agent)
        if raid(hero_id, map) 
          map.visit!
        end
      else
        $logger.info 'No maps available.'
      end
    end
  end

  def raid(hero_id, map)
    select_hero = @agent.get("http://#{SERVER}.dragon2.bg-time.jp/outarms.ql?from=map&m=2")
    confirm = select_hero.form_with(:action => '/outarms.ql') do |f|
      unless f
        $logger.info "Hero:#{hero_id} in raid."
        return false
      end
      if hero_checkbutton = f.checkbox_with(:value => hero_id)
        hero_checkbutton.check
      else
        $logger.info "Hero:#{hero_id} in raid."
        return false
        raise "Hero:#{hero_id} not available."
      end
      f.radiobuttons_with(:name => 'm').each{|radio| radio.check if radio.value == 2 }
      f.x = map.x
      f.y = map.y
    end.submit
    result = confirm.form_with(:action => '/outarms.ql').submit
    #TODO 成功したか判定
    $logger.info "Raid (#{map.x}|#{map.y}) #{map.map_type} with hero : #{hero_id}."
    return true
  end

  def levelup(hero_id)
    while link = @agent.get(URL[:hero] + hero_id).link_with(:href => /hero\/upgrade.ql\?heroId=\d+/)
      delay
      link.click
      $logger.info "Hero level up : #{hero_id}."
    end
  end

  # 都市の座標を返す
  # [[111, -92], [111, -91]]
  def cities
    @cities ||= @agent.get(URL[:index]).parser.xpath("//a[@class='city']").inject([]) do |cities, element|
      cities << /\(([-]*\d+)\s*\|\s*([-]*\d+)\)/.match(element['title']).to_a[1,2].map{|i| i.to_i}
      cities
    end
  end
end
