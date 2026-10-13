# Loan dates are relative to today so the reminder jobs always have something to send right after `docker compose up`.

readers = [
  [ "100001", "Ada Lovelace", "ada.lovelace@example.com" ],
  [ "100002", "Alan Turing", "alan.turing@example.com" ],
  [ "100003", "Grace Hopper", "grace.hopper@example.com" ],
  [ "100004", "Edsger Dijkstra", "edsger.dijkstra@example.com" ],
  [ "100005", "Barbara Liskov", "barbara.liskov@example.com" ]
].to_h do |card_number, full_name, email|
  reader = Reader.find_or_create_by!(card_number: card_number) do |r|
    r.full_name = full_name
    r.email = email
  end
  [ card_number, reader ]
end

books = [
  [ "000001", "Pride and Prejudice", "Jane Austen" ],
  [ "000002", "Nineteen Eighty-Four", "George Orwell" ],
  [ "000003", "The Master and Margarita", "Mikhail Bulgakov" ],
  [ "000004", "Solaris", "Stanisław Lem" ],
  [ "000005", "The Hobbit", "J.R.R. Tolkien" ],
  [ "000006", "Dune", "Frank Herbert" ],
  [ "000007", "The Left Hand of Darkness", "Ursula K. Le Guin" ],
  [ "000008", "Quo Vadis", "Henryk Sienkiewicz" ],
  [ "000009", "The Pragmatic Programmer", "Andrew Hunt, David Thomas" ],
  [ "000010", "Practical Object-Oriented Design in Ruby", "Sandi Metz" ],
  [ "000011", "Crime and Punishment", "Fyodor Dostoevsky" ],
  [ "000012", "One Hundred Years of Solitude", "Gabriel García Márquez" ]
].to_h do |serial_number, title, author|
  book = Book.find_or_create_by!(serial_number: serial_number) do |b|
    b.title = title
    b.author = author
  end
  [ serial_number, book ]
end

loan_period_days = Borrowing::LOAN_PERIOD.in_days.to_i
today = Time.current

[
  [ "000001", "100001", 120, 100 ],
  [ "000001", "100002", 60, 35 ],
  [ "000002", "100003", 90, 70 ],
  [ "000001", "100003", loan_period_days - 3, nil ], # "due_soon" reminder
  [ "000002", "100001", loan_period_days, nil ], # "due_today" reminder
  [ "000003", "100004", 10, nil ],
  [ "000004", "100005", 1, nil ],
  [ "000005", "100002", loan_period_days - 3, nil ] # "due_soon" reminder
].each do |serial_number, card_number, borrowed_days_ago, returned_days_ago|
  book = books.fetch(serial_number)
  borrowed_at = (today - borrowed_days_ago.days).change(hour: 10)
  next if book.borrowings.exists?(borrowed_at: borrowed_at.all_day)

  book.borrowings.create!(
    reader: readers.fetch(card_number),
    borrowed_at: borrowed_at,
    returned_at: returned_days_ago && (today - returned_days_ago.days).change(hour: 16)
  )
end

puts "Seeded #{Reader.count} readers, #{Book.count} books, #{Borrowing.count} borrowings " \
     "(#{Borrowing.active.count} active)."
