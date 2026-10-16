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
| 404 | `about:blank` | No book with that serial number. |
| 409 | `urn:library-api:problem:book-borrowed` | The book is currently borrowed, so it can't be deleted or borrowed again. |
| 409 | `urn:library-api:problem:book-not-borrowed` | Returning a book that isn't borrowed. |
| 422 | `urn:library-api:problem:validation-failed` | The request is well-formed but breaks a domain rule, such as a duplicate serial number or an unknown library card number. |

The split between 400 and 422 follows the split between layers: 400 means the request doesn't match the contract, and 422 means it matches the contract but the domain rejected it.

### Contract: OpenAPI 3.0 in `docs/openapi.yaml`

The API is described by a hand-written [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3) document, `docs/openapi.yaml`. It is the single source of truth for paths, parameters, request bodies, responses and error types. Its schemas are written in the OpenAPI Schema Object, which is an extended subset of JSON Schema.

The document itself isn't written yet. It will be added together with the endpoints, once their full shape is settled. Until then, this ADR defines the conventions it has to follow.

The contract is enforced in two places with [`committee`](https://github.com/interagent/committee):

- **Requests, at runtime.** `Committee::Middleware::RequestValidation` runs in the Rails middleware stack and validates the parameters and bodies of every request against `docs/openapi.yaml`. Invalid requests are rejected with 400 and never reach a controller. A custom committee error class renders these errors as `application/problem+json`. Request bodies set `additionalProperties: false`, so unknown fields are rejected rather than silently ignored.
- **Responses, in tests.** Request specs call `assert_response_schema_confirm` from [`committee-rails`](https://github.com/willnet/committee-rails) for every response, so a response that doesn't match the contract fails the suite. Responses aren't validated at runtime, because that would slow down every request to catch bugs the specs already catch.

Responsibilities are split between the layers:

- **The schema checks shape:** required fields, types, formats, patterns and enums (for example, `serial_number` matches `^\d{6}$`, and `status` is `available` or `borrowed`).
- **Domains check business rules:** uniqueness, whether a reader exists, whether a book can be borrowed or returned. These rules aren't repeated in the schema, which couldn't enforce most of them anyway. Database constraints remain the last line of defence.

## Alternatives considered

- **JSON:API ([jsonapi.org](https://jsonapi.org)):** a recognised standard with a defined error format, compound documents (`include=borrowings.reader`), sparse fieldsets and pagination links. With five endpoints, most of that would go unused, and the `data`/`attributes`/`relationships` structure makes every response harder to read with curl. The Ruby serializers built for it (`jsonapi-serializer`, `jsonapi-rb`) have seen little recent activity.
- **Ad-hoc error bodies (`{"error": "..."}`) or the Rails default error format:** less to write, but there is no standard shape and no machine-readable error type, so each client has to parse messages.
- **[`rswag`](https://github.com/rswag/rswag):** request specs written in its DSL generate the OpenAPI document and serve Swagger UI. The documentation is then derived from the tests instead of being a contract the tests check, and the specs are shaped by the documentation DSL. It also doesn't validate incoming requests at runtime.
- **Standalone JSON Schema files with `json_schemer` or `json_matchers`:** full, current JSON Schema, but no description of paths, parameters or status codes. Mapping schemas to endpoints and validating requests would be custom code.
- **Request validation in controllers (strong parameters, `dry-validation`):** works, but duplicates the contract in Ruby, and the documentation would be a separate artifact that can drift.
- **OpenAPI 3.1:** its schemas are full JSON Schema 2020-12. However, committee and its parser target OpenAPI 3.0, and their support for 3.1 couldn't be confirmed. 3.0.3 is fully supported, and the document can be migrated to 3.1 once the tooling supports it.

## Consequences

- (+) The whole API is described in one document that a reviewer can read, or import into Swagger UI or Postman.
- (+) Controllers and domains can assume requests have the documented shape. Malformed input is rejected in one place, with a consistent error.
- (+) Every request spec checks its response against the contract, so the documentation can't silently drift from responses covered by the specs.
- (+) Errors are consistent and machine-readable: clients branch on `type` and `status`, and can map `errors[].pointer` to form fields.
- (−) The contract is written by hand, so every API change touches both `docs/openapi.yaml` and the code. Drift is caught only for requests and responses the specs exercise.
- (−) `committee` and `committee-rails` are extra dependencies, and their compatibility with Ruby 4.0 and Rails 8.1 still has to be verified when they're added.
- (−) OpenAPI 3.0 schemas aren't full JSON Schema. For example, nullable fields use `nullable: true` rather than `type: [string, "null"]`.
- (−) Clients see two error statuses for invalid input (400 for shape, 422 for domain rules), which they have to handle separately.
- (−) The `urn:` problem types are stable identifiers, but they don't resolve to documentation. Their meaning is documented only in `docs/openapi.yaml` and this ADR.
