# Handle interrupt signals so we can gracefully exit during uploads
$exit = 0

Signal.trap("INT") do
  $exit += 1

  if $exit == 1
    puts "Caught Ctrl-C, exiting after this upload..."
  elsif $exit > 1
    puts "Exiting immediately."
    exit(1)
  end
end
