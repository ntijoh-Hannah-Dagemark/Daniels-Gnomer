require 'sqlite3'

class Seeder

def self.seed!
    drop_tables
    create_tables


    # FOR DEVELOPMENT
    seed_tables
    # FOR DEVELOPMENT


end

def self.db
    if @db == nil
        @db = SQLite3::Database.new('./db/db.sqlite')
        @db.results_as_hash = true
    end
    return @db
end

def self.drop_tables
    db.execute('DROP TABLE IF EXISTS people')
end

def self.create_tables
    db.execute('CREATE TABLE people(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filepath TEXT NOT NULL
    )')
end



# FOR DEVELOPMENT
def self.seed_tables

    people = [
        {name: 'Hej1', filepath: './../public/img/1.png'},
        {name: 'Hej2', filepath: './../public/img/2.png'},
    ]

    people.each do |people|
        db.execute('INSERT INTO people (name, filepath) VALUES (?,?)', [people[:name], people[:filepath]])
    end

end
# FOR DEVELOPMENT



end