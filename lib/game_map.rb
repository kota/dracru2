# -*- coding: utf-8 -*-
class GameMap < ActiveRecord::Base
  include Core

  AJAX_CONTENT_TYPE = 'application/x-www-form-urlencoded; charset=UTF-8'
  
  class << self
    include Core
    
    def get_available_map(agent,include_akuma=true)
      now = Time.now
      if AKUMA
        # 60分以内にチェックした悪魔城は対象外
        conditions = ['akuma_checked_at < ? and visited_at != ?', 60.minutes.ago, now.beginning_of_day]
        order = "akuma desc, random()" 
      else 
        conditions = ['visited_at != ?', now.beginning_of_day]
        order = "random()"
      end
      unless include_akuma
        conditions[0] += ' and akuma = ?'
        conditions << false;
      end
      # 30回マップ探索してダメならあきらめる
      for i in 1..30
        map = GameMap.find(:first, :conditions => conditions,:order => order)
        html = agent.get(URL[:mapinfo] + map.mapid).body
        doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')
        delay
        text = doc.xpath("//div[@class='map_info']/h3").text
        if text.split('(')[0] == '悪魔城廃墟'
          map.no_akuma
        else
          return map
        end
      end
      return nil
    end
    
    def generate_maps(agent, city)
      get_centers_of_neighbour(city[0], city[1], RAID_DISTANCE).each do |coord|
        get_maps(agent, coord[:x], coord[:y]).each do |k,v|
          if ['丘陵','森林','湿地','山地','悪魔城'].include?(v['name'])
            # typeが17だと悪魔城
            map_data = {:x => v['x'], :y => v['y'], :mapid => k, :akuma => v['type'] == 17, :map_type => v['name']}
            GameMap.create(map_data)
            $logger.info "map created #{map_data}"
          end
        end
      end
    end
    
    def get_maps(agent, center_x, center_y)
      ids = get_map_ids(center_x, center_y)
      json = "json={'mapIds':'#{ids.join(',')}'}"
      map = agent.post(URL[:ajaxmap], json, 'Content-Type' => AJAX_CONTENT_TYPE)
      delay
      JSON.parse(map.body)
    end
  end

  def visit!
    self.visited_at = Time.now.beginning_of_day
    self.save!
  end
  
  def no_akuma!
    self.akuma_checked_at = Time.now
    self.save!
    $logger.info "Map (#{self.x}|#{self.y}), 悪魔城廃墟 tt"
  end
  
  private

  #distance = 画面単位ではかった距離
  # ex. distance = 1
  # * * *
  # * c *
  # * * *
  #
  # ex. ditance = 2
  # * * * * *
  # *       *
  # *   c   *
  # *       *
  # * * * * *
  #
  # return 上図*の画面の中心座標の配列
  #
  def self.get_centers_of_neighbour(center_x, center_y, distance)
    centers = []
    dist_in_grids = distance * 9
    (distance*2+1).times do |i| 
      diff = i*9
      centers.push({:x => center_x-dist_in_grids+diff, :y => center_y-dist_in_grids})
      centers.push({:x => center_x-dist_in_grids,      :y => center_y-dist_in_grids+diff})
      centers.push({:x => center_x+dist_in_grids-diff, :y => center_y+dist_in_grids})
      centers.push({:x => center_x+dist_in_grids,      :y => center_y+dist_in_grids-diff})
    end
    centers.uniq
  end

  def self.get_map_ids(center_x, center_y)
    ids = []
    (-4..4).each do |x|
      (-4..4).each do |y|
        ids.push(get_map_id(center_x+x, center_y+y))
      end
    end
    ids
  end

  def self.get_map_id(x,y)
    ((x+5000)*10000)+y+5000
  end

end
