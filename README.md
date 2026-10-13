# Library API

An API-only Rails app that taht can be used to create and track books - who has them, and when they are due.
Readers will receive an email reminder 3 days before and on the due date (loans last 30 days).

**Stack:** Ruby 3.4, Rails 8.1 (API-only), PostgreSQL, Sidekiq + sidekiq-cron on Redis, RSpec.

## Running it

```sh
docker compose up
```

This starts four services:

* db - PostgreSQL 17
* redis - Redis 7 - used for Sidekiq queue and cron registry
* web - Rails API on http://localhost:3000. First boot creates and seeds the DB.
* sidekiq - Runs background jobs and the daily reminder schedule (`config/schedule.yml`)

If port 3000 is already taken, choose another one: `WEB_PORT=3100 docker compose up`.


* Sidekiq dashboard: http://localhost:3000/sidekiq. I know we have asked just for the API but I figured we can leave it in for now, it's one line of code to remove it
* Sent emails are written to the log: `docker compose logs -f sidekiq`.
* Mailer previews: http://localhost:3000/rails/mailers.
* Tests inside Docker: `docker compose run --rm -e RAILS_ENV=test web sh -c "bin/rails db:prepare && bundle exec rspec"`.

Running locally without Docker: `bin/setup`, then `bin/rails s` and `bundle exec sidekiq -C config/sidekiq.yml`.
Postgres and Redis come from `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` / `REDIS_URL`; when unset, the local defaults are used.

## API

All endpoints are under `/api/v1` and take and return JSON.
Records contain id fields but for both books and readers we go by their serial/card number instead.

| method   | path                                     | description                                              |
|----------|------------------------------------------|----------------------------------------------------------|
| `GET`    | `/books?status=&page=&per_page=`         | List books with their status (`available` / `borrowed`) |
| `GET`    | `/books/:serial_number`                  | Book details and full borrowing history, newest first   |
| `POST`   | `/books`                                 | Add a book                                               |
| `DELETE` | `/books/:serial_number`                  | Delete a book (`409` if it is currently borrowed)       |
| `PATCH`  | `/books/:serial_number/status`           | Borrow or return a book                                  |
| `GET`    | `/readers`, `/readers/:card_number`      | List / show readers                                      |
| `POST`   | `/readers`                               | Register a reader                                        |

```sh
# add a book
curl -X POST localhost:3000/api/v1/books -H 'Content-Type: application/json' \
  -d '{"book": {"serial_number": "123456", "title": "Solaris", "author": "Stanisław Lem"}}'

# lend it to reader 100001 (due in 30 days)
curl -X PATCH localhost:3000/api/v1/books/123456/status -H 'Content-Type: application/json' \
  -d '{"status": "borrowed", "card_number": "100001"}'

# it came back
curl -X PATCH localhost:3000/api/v1/books/123456/status -H 'Content-Type: application/json' \
  -d '{"status": "available"}'

# details and history
curl localhost:3000/api/v1/books/123456
```

```json
{
  "serial_number": "123456",
  "title": "Solaris",
  "author": "Stanisław Lem",
  "status": "available",
  "current_borrowing": null,
  "borrowings": [
    {
      "borrowed_at": "2026-10-11T09:00:00.000Z",
      "due_date": "2026-11-10",
      "returned_at": "2026-10-12T15:30:00.000Z",
      "reader": { "card_number": "100001", "full_name": "Testowy Pan", "email": "testowy.pan@example.com" }
    }
  ]
}
```

List endpoints return `{ "books": [...], "meta": { "page", "per_page", "total_count" } }`. `per_page` defaults to 25 and is capped at 100.
Errors always come back as `{ "errors": ["..."] }`, with these status codes:

* `400`: a required parameter is missing.
* `404`: the book or reader does not exist.
* `409`: the action conflicts with the book's current state, for instance attempting to borrow an already borrowed book or trying to delete one that's still borrowed.
* `422`: validation failed, the status is missing or unknown, or the card number is unknown.

## Design notes

There are three tables: `books`, `readers` and `borrowings`. A book's status is not stored directly, instead we derive it
from whether the book has an *active* borrowing (`returned_at IS NULL`).

### Indexes + validation

* `NOT NULL` columns and foreign keys.
* Unique indexes on `books.serial_number`, `readers.card_number` and `readers.email`. Emails are normalized to lowercase.
* `CHECK` constraints for the six-digit numbers. These are stored as strings so leading zeros (`000042`) survive.
* A **partial unique index** `borrowings(book_id) WHERE returned_at IS NULL` for books which haven't been returned yet to simplify our search for notifications

**Reminders.** The work is split between two jobs in `app/jobs/reminders`:

So I wasn't sure how large of a dataset we are really working with. I assumed it can be sizeable but not gigantic so no partitioning.
Instead we split all the work in a scheduler first which creates batches of 500 requests and sends them over for sending. Scheduler cannot start the work
if we still have active on going SendReturnJob instances going (to prevent duplication and sending the same ids).

If a batch fails - we try 3 more times, within an hour total. This way we can't send a reminder a day later for instance.

I didn't want to overengineer it so we currently stop an entire batch if a request fails.

`config/schedule.yml` registers two daily sidekiq-cron entries: `due_soon` at 08:00 UTC and `due_today` at 08:05 UTC. 
Each enqueues `Reminders::SchedulerJob` with its reminder kind.

**Emails.** We don't send anything. There's a fake delivery method in (`config/initializers/log_mail_delivery.rb`) which writes
the full message to the Rails log. Text templates are in `app/views/return_reminder_mailer`.

**Tests.** 

RSpec + FactoryBot + should-matchers.

**Disclaimer**

I have used some AI to build this. 
But I tried to keep it reasonable and not let it turn into a spaghetti monster.