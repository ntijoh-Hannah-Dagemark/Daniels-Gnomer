require 'sinatra'
require 'sinatra/flash'
require 'sqlite3'
require 'fileutils'
require 'bcrypt'
require 'zip'
require 'fileutils'
require_relative 'db/seed'

class App < Sinatra::Base
  enable :sessions
  register Sinatra::Flash

  # Database connection
  def db
    @db ||= SQLite3::Database.new('./db/db.sqlite').tap do |db|
      db.results_as_hash = true
    end
  end

  # --- Routes for managing people ---

  # Add a person with an uploaded file
  post '/manage/add-person' do

    uploadDir = './public/img/'
    if params['fileupload'] && params['fileupload']['tempfile'] && params['fileupload']['filename']
      file = params['fileupload']
      filename = "#{next_id}.png"
      tempfile = file['tempfile']
      name = params['name']

      filepath = File.join(uploadDir, filename)
      relpath = "/img/#{filename}"

      FileUtils.cp(tempfile.path, filepath)

      db.execute('INSERT INTO people (name, filepath) VALUES (?, ?)', [name, relpath])
      flash[:success] = "File uploaded successfully as #{filename}"
      redirect '/manage'
    else
      flash[:notice] = 'Failed to upload file: No file found'
      redirect '/manage'
    end
  end

  # Remove a person with given ID
  post '/manage/remove-person' do
    db.execute('DELETE FROM people WHERE id = ?', params['number'])

    flash[:success] = "Person with ID #{params['number']} successfully removed"
    redirect '/manage'
  end

  # Get the next ID for new entries
  def next_id
    result = db.execute('SELECT id FROM people ORDER BY id DESC LIMIT 1').first
    result ? result['id'] + 1 : 1
  end

  # Manage interface - show all people
  get '/manage' do
    if session[:user_id].nil?
        redirect '/login/login'
    end

    if !table_exists?('people')
      @db_content = "empty"
    else
        @db_content = db.execute("SELECT * FROM people")
    end
    erb :manage
  end

  # --- Routes for user authentication ---

  # Handle user login and registration
  post '/login' do
    case params['user-value']
    when 'login'
      handle_login
    when 'register'
      handle_registration
    else
      flash[:notice] = 'Invalid action'
      redirect '/login/login'
    end
  end

  # Handle user login
  def handle_login
    user = db.execute('SELECT * FROM users WHERE username = ?', params['username']).first
    print("User is #{user}")
    if user.nil?
      flash[:notice] = 'Username not found'
      redirect '/login/login'
    end

    pass_encrpt = BCrypt::Password.new(user['password'])
    print("Comparing #{params['password']} to #{pass_encrpt}")
    if pass_encrpt == params['password'] 
        flash[:success] = "Logged in Successfully"
      session[:user_id] = user['id']
      redirect '/'
    else
      flash[:notice] = 'Password Incorrect'
      redirect '/login/login'
    end
  end

  # Handle user registration
  def handle_registration
    if params['password'] != params['password-check']
      flash[:notice] = 'Password mismatch'
      redirect '/login/signup'
    end

    hashed_password = BCrypt::Password.create(params['password'])
    db.execute('INSERT INTO users (username, password) VALUES (?, ?)', [params['username'], hashed_password])
    redirect '/login/login'
  end

  # Show login or signup form
  get '/login/:type' do |type|
    if session[:user_id]
      redirect("/")
    end
    @login = type
    erb :login
  end

  get '/login' do
    redirect '/login/login'
  end
  # --- Routes for game functionality ---

  # Show game page with ID
  get '/game/:id' do |id|
    if table_exists?('people')
      @people_db = db.execute('SELECT * FROM people')
      @game_id = id
      erb :game
    else
      redirect '/manage'
    end
  end

  # Post answer to game
  post '/game' do
    game_id = params["game_id"]
    ansr = params['answer']
    imgid = params['img_id']
    user_id = session[:user_id]

    correct = db.execute('SELECT name FROM people WHERE id = ?', imgid).first['name']

    if ansr == correct
        flash[:notice] = 'Correct'
        adjust_rating(imgid, user_id, true)
    else
        flash[:notice] = "Incorrect, it should be #{correct}"
        adjust_rating(imgid, user_id, false)  
    end    

    redirect "/game/#{game_id}"
  end

  def adjust_rating(person_id, user_id, is_correct)
    
    existing_rating = db.execute('SELECT pos_rating, neg_rating FROM ratings WHERE person_id = ? AND user_id = ?', [person_id, user_id]).first

    if existing_rating
        pos_rating = existing_rating['pos_rating']
        neg_rating = existing_rating['neg_rating']

        if is_correct
        pos_rating += 1
        else
        neg_rating += 1
        end

        total_attempts = pos_rating + neg_rating
        avg_rating = ((pos_rating.to_f / total_attempts) * 10).round(1)

        print("Updated rating: Positive - #{pos_rating}, Negative - #{neg_rating}, Average - #{avg_rating}\n")
        db.execute('UPDATE ratings SET pos_rating = ?, neg_rating = ?, avg_rating = ? WHERE person_id = ? AND user_id = ?', [pos_rating, neg_rating, avg_rating, person_id, user_id])
    else
        pos_rating = is_correct ? 1 : 0
        neg_rating = is_correct ? 0 : 1
        avg_rating = is_correct ? 10.0 : 0.0

        print("Created new rating: Positive - #{pos_rating}, Negative - #{neg_rating}, Average - #{avg_rating}\n")
        db.execute('INSERT INTO ratings (person_id, user_id, pos_rating, neg_rating, avg_rating) VALUES (?, ?, ?, ?, ?)', [person_id, user_id, pos_rating, neg_rating, avg_rating])
    end
  end
  # --- Miscellaneous ---

  # Set default database
  get '/manager/default' do
    $type = "default"
    load './db/default.rb'
    flash[:success] = 'Database defaulted successfully'
    redirect '/manage'
  end

  # Delete all entries from the database
  get '/manager/delete-all' do
    $type = "delete"
    load './db/default.rb'
    redirect '/manage'
  end

  # Home page redirection
  get '/' do
    redirect session[:user_id] ? '/index' : '/login/login'
  end

  # Show index page
  get '/index' do
    redirect '/login/login' if session[:user_id].nil?
    erb :index
  end

  get '/profile' do
    @people_rated = db.execute('SELECT * FROM ratings INNER JOIN people ON people.id = ratings.person_id WHERE user_id = ?', session[:user_id])
    erb :profile
  end

  # Utility to check if a table exists
  def table_exists?(table_name)
    result = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", [table_name])
    !result.empty?
  end


  post '/manage/upload' do

    print("\n\nZip bulk upload from user #{session[:user_id]} begun\n\n")

    # Check if a file has been uploaded and ensure it is a ZIP file
    if params[:zip_file].nil?
      flash[:notice] = "No file found"
      redirect '/manage'
    end

    if File.extname(params[:zip_file][:filename]) != '.zip'
      flash[:notice] = "Uploaded file is not a ZIP file"
      redirect '/manage'
    end

    # Save the ZIP file temporarily
    temp_zip = params[:zip_file][:tempfile]
    print "Temporary ZIP file path: #{temp_zip.path}\n"
    print "Uploaded ZIP file details: #{params[:zip_file]}\n"

    # Create the directory for uploaded files if it doesn't exist
    upload_dir = 'public/uploads'
    print "Upload directory: #{upload_dir}\n"

    # Define the extraction directory
    extraction_dir = File.join(upload_dir, 'extracted')
    FileUtils.mkdir_p(extraction_dir)
    print "Extraction directory: #{extraction_dir}\n"

    # Use system command to unzip the file
    unzip_command = "unzip -o #{temp_zip.path} -d #{extraction_dir}"
    print "Running command: #{unzip_command}\n"
    system(unzip_command)

    # Check if the unzip command was successful
    if $?.exitstatus != 0
      flash[:notice] = "An error occurred while processing the ZIP file."
      redirect '/manage'
    end

    # Process extracted files
    Dir.glob(File.join(extraction_dir, '**', '*')).each do |file|
      next unless File.file?(file) # Skip directories and other non-file entries

      print "Processing file: #{file}\n"
      
      # Extract filename and extension
      filename_with_extension = File.basename(file)
      filename_without_extension = File.basename(file, File.extname(file))
      relpath = "/uploads/downloaded/#{filename_with_extension}"
      filepath = File.join(upload_dir, 'downloaded', filename_with_extension)
      
      print "Filename without extension: #{filename_without_extension}\n"
      print "Saving file to: #{filepath}\n"

      # Move the file to the public folder
      FileUtils.mv(file, filepath)

      # Save the information in the database
      db.execute("INSERT INTO people (name, filepath) VALUES (?, ?)", [filename_without_extension, relpath])
      print "Database entry created for: #{filename_without_extension}, #{relpath}\n"
    end

    print "ZIP file extraction and processing completed\n"

    # Redirect back to /manage after the upload is complete
    redirect '/manage'
  end
end