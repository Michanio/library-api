# 5. Use plain JSON with RFC 9457 errors and an OpenAPI contract

Date: 2026-10-16
Status: Accepted

## Context

The brief asks for "a simple API" for library staff and leaves the format and everything else open ("in all other aspects, you are free to choose your approach"). Before writing endpoints, we need to decide three things:

- **Response shape.** Every endpoint should follow the same conventions for keys, collections, dates and identifiers, so clients don't have to special-case each one.
- **Error shape.** Clients need to tell "the request was malformed" apart from "the book is already borrowed", and to know which field a validation error refers to.
- **Contract and validation.** The reviewer should be able to read what the API accepts and returns without reading the code. The documented contract must not drift from what the app actually does, and malformed requests should be rejected before they reach controllers and domains.

Some data needs explicit rules. Serial numbers and library card numbers are "six-digit numbers", so `000123` has to stay distinguishable from `123`. A book's status is derived from its open borrowing (see the planned data model in the README), not stored.

## Decision

### Response format: plain JSON

Responses use `application/json` with no envelope standard on top. The conventions are:

- **Keys are `snake_case`**, matching Ruby and the database.
- **A single resource is returned as a bare object** (`{"serial_number": "000123", ...}`).
- **A collection is wrapped in an object keyed by the resource name** (`{"books": [...]}`), so metadata such as pagination can be added later without a breaking change.
- **Six-digit identifiers are strings** matching `^\d{6}$`. As integers they would lose leading zeros.
- **Books are addressed by serial number in URLs** (`/books/000123`). Internal database IDs aren't exposed.
- **Timestamps are RFC 3339 `date-time` strings in UTC.** The due date is a `date` (`due_on`), because a loan is due on a day, and reminders are sent per day.
- **Book status is a derived field**, `"status": "available" | "borrowed"`.
- **State transitions are action endpoints**: `POST /books/{serial_number}/borrow` (body: the reader's library card number) and `POST /books/{serial_number}/return` (no body), each returning the updated book. They implement the brief's "update the book status" requirement. The intent is in the URL, so each request body has one strict schema, and each endpoint maps to one domain operation (`Lending.borrow`, `Lending.return`). We prefer this to a generic `PATCH /books/{serial_number}/status`, which needs a body that says which transition is meant, and to modelling borrowings as a separate resource that has no use of its own yet.

### Errors: RFC 9457 problem details

Every error response uses `application/problem+json` as defined in [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457):

```json
{
  "type": "urn:library-api:problem:validation-failed",
  "title": "Validation failed",
  "status": 422,
  "detail": "The book could not be saved.",
  "errors": [
    { "pointer": "/serial_number", "detail": "has already been taken" }
  ]
}
```

- `type` identifies the kind of problem. Domain-specific problems use URNs (`urn:library-api:problem:<slug>`), and errors that need nothing beyond the HTTP status (such as 404) use `about:blank`, as RFC 9457 recommends.
- The `errors` extension member lists field-level errors. `pointer` is a JSON Pointer ([RFC 6901](https://www.rfc-editor.org/rfc/rfc6901)) into the request body.

Status codes:

| Status | `type` | When |
|---|---|---|
| 400 | `urn:library-api:problem:invalid-request` | The body isn't valid JSON or doesn't match the OpenAPI schema (wrong type, missing or unknown field, bad format). |
| 405, 415 | `about:blank` | The method isn't documented for the path, or the request's content type isn't. |
| 404 | `about:blank` | No book with that serial number. |
| 409 | `urn:library-api:problem:book-borrowed` | The book is currently borrowed, so it can't be deleted or borrowed again. |
| 409 | `urn:library-api:problem:book-not-borrowed` | Returning a book that isn't borrowed. |
| 422 | `urn:library-api:problem:validation-failed` | The request is well-formed but breaks a domain rule, such as a duplicate serial number or an unknown library card number. |

The split between 400 and 422 follows the split between layers: 400 means the request doesn't match the contract, and 422 means it matches the contract but the domain rejected it.

### Contract: OpenAPI 3.1 in `docs/openapi.yaml`, enforced with `openapi_first`

The API is described by a hand-written [OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0) document, `docs/openapi.yaml`. It is the single source of truth for paths, parameters, request bodies, responses and error types. Its schemas are JSON Schema 2020-12.

The document is loaded once at boot (`config/initializers/openapi_first.rb`) and enforced with [`openapi_first`](https://github.com/ahx/openapi_first), in two places:

- **Requests, at runtime.** A `before_action` in `ApplicationController` validates the path, query and body of every request against the contract. An invalid request is answered with a problem (usually 400) and never reaches the action. Request bodies set `additionalProperties: false`, so unknown fields are rejected rather than silently ignored. Patterns are evaluated as ECMA-262 regular expressions, as OpenAPI requires; in Ruby's dialect `$` would also match before a trailing newline.
- **Responses and coverage, in tests.** `OpenapiFirst::Test` observes the Rails app in request specs. Every request and response is validated against the contract, and a mismatch fails the spec. It also tracks which documented responses the specs exercised, and fails the suite when any of them were never exercised. Responses aren't validated at runtime, because that would slow down every request to catch bugs the specs already catch.

Validation runs in a controller callback rather than in the gem's Rack middleware, for three reasons. The middleware rejects every path missing from the contract, including Rails' `/up` health check. Contract errors and domain errors are both rendered by `ApplicationController`, so there's one renderer for problem details. And the middleware's custom error class would have to be loaded during boot, outside Rails' autoloading.

Responsibilities are split between the layers:

- **The schema checks shape:** required fields, types, formats, patterns and enums (for example, `serial_number` matches `^\d{6}$`, and `status` is `available` or `borrowed`).
- **Domains check business rules:** uniqueness, whether a reader exists, whether a book can be borrowed or returned. These rules aren't repeated in the schema, which couldn't enforce most of them anyway. Database constraints remain the last line of defence.

## Alternatives considered

- **JSON:API ([jsonapi.org](https://jsonapi.org)):** a recognised standard with a defined error format, compound documents (`include=borrowings.reader`), sparse fieldsets and pagination links. With five endpoints, most of that would go unused, and the `data`/`attributes`/`relationships` structure makes every response harder to read with curl. The Ruby serializers built for it (`jsonapi-serializer`, `jsonapi-rb`) have seen little recent activity.
- **Ad-hoc error bodies (`{"error": "..."}`) or the Rails default error format:** less to write, but there is no standard shape and no machine-readable error type, so each client has to parse messages.
- **[`rswag`](https://github.com/rswag/rswag):** request specs written in its DSL generate the OpenAPI document and serve Swagger UI. The documentation is then derived from the tests instead of being a contract the tests check, and the specs are shaped by the documentation DSL. It also doesn't validate incoming requests at runtime.
- **Standalone JSON Schema files with `json_schemer` or `json_matchers`:** full, current JSON Schema, but no description of paths, parameters or status codes. Mapping schemas to endpoints and validating requests would be custom code.
- **Request validation in controllers (strong parameters, `dry-validation`):** works, but duplicates the contract in Ruby, and the documentation would be a separate artifact that can drift.
- **[`committee`](https://github.com/interagent/committee) with `committee-rails`:** the most widely used Ruby option, with request validation middleware and a response assertion for tests. Its parser targets OpenAPI 3.0, whose schemas are only a subset of JSON Schema, and we couldn't confirm support for 3.1. It also has no coverage tracking, so documented responses that no spec exercises go unnoticed.
- **[`skooma`](https://github.com/skryukov/skooma):** supports OpenAPI 3.1 and tracks coverage, but only validates in tests, so requests would need a second validation mechanism at runtime.
- **`openapi_first`'s Rack middleware** instead of a controller callback: see the reasons above.

## Consequences

- (+) The whole API is described in one document that a reviewer can read, or import into Swagger UI or Postman.
- (+) Controllers and domains can assume requests have the documented shape. Malformed input is rejected in one place, with a consistent error.
- (+) Every request spec checks its request and response against the contract, and coverage tracking fails the suite when a documented response is never exercised, so the documentation can't silently drift from the code.
- (+) Errors are consistent and machine-readable: clients branch on `type` and `status`, and can map `errors[].pointer` to form fields.
- (−) The contract is written by hand, so every API change touches both `docs/openapi.yaml` and the code.
- (−) With strict coverage, a run of a single spec file reports the rest of the contract as uncovered, so strict coverage has to be limited to full-suite runs.
- (−) `openapi_first` is less widely known than committee, and it's one more runtime dependency.
- (−) Because validation runs after routing, a URL that matches no route gets Rails' default 404 rather than a problem details response.
- (−) The contract is loaded at boot, so in development the server has to be restarted after `docs/openapi.yaml` changes.
- (−) Clients see two error statuses for invalid input (400 for shape, 422 for domain rules), which they have to handle separately.
- (−) The `urn:` problem types are stable identifiers, but they don't resolve to documentation. Their meaning is documented only in `docs/openapi.yaml` and this ADR.
