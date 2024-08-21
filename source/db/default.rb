require 'sqlite3'
require_relative 'seed'

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
    print "DEFAULTING DATABASE...\n"
    self.remove
    self.create()
    print("DATABASE DEFAULTED\n")
  end

  def self.remove
    print "DELETING DATABASE\n"
    path = "./public/img"
    imgs = Dir.glob("#{path}/*.jpeg")
    print "IDENTIFIED #{imgs.length} IMAGES TO DELETE\n"
    imgs.each do |img|
      FileUtils.rm(img)
    end
    Seeder.seed!
    print "DELETED FILES AND CLEARED DATABASE\n"
  end

  def self.create
    print "GENERATING DEFAULT SET\n"
    path = "./public/img/defaults"
    imgs = Dir.glob("#{path}/*.jpeg")
    print "IDENTIFIED #{imgs.length} DEFAULTS\n\n"
    people = []
    imgs.each do |img|
      name = File.basename(img, '.jpeg')
      people.append({name: "#{name}", filepath: "/img/#{name}.jpeg"})
      print "Loaded #{name}\n"
    end

    people.each do |people|
        db.execute('INSERT INTO people (name, filepath) VALUES (?,?)', [people[:name], people[:filepath]])
    end
  end
end

Defaulter.default