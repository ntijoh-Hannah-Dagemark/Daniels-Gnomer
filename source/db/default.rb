require 'sqlite3'

class Defaulter

  def self.db
      if @db == nil
          @db = SQLite3::Database.new('./db/db.sqlite')
          @db.results_as_hash = true
      end
      return @db
  end


  # FOR DEVELOPMENT
  def self.default
    print "DEFAULTING DATABASE..."
    path = "./public/img/defaults"
    imgs = Dir.glob("#{path}/*.jpeg")
    print "IDENTIFIED #{imgs.len} DEFAULTS"
    people = []
    imgs.each do |img|
      name = File.basename(img, '.jpeg')
      people.append({name: "#{name}", filepath: "/img/#{name}.jpeg"})
    end

    people.each do |people|
        db.execute('INSERT INTO people (name, filepath) VALUES (?,?)', [people[:name], people[:filepath]])
    end
    print("DATABASE DEFAULTED")
  end
end

Defaulter.default