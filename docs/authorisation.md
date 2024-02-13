# Authorisation

In some cases, assets should not be publicly accessible. This only applies when they are in the "draft" state, which typically
means that they are associated with a content item which is present on the "draft" stack in content store, but not present on the "live" stack.
All assets associated with "live" content must be publicly available.

There are three types of authorisation that can be applied to assets in the "draft" state:

- Authorisation based on the user ID
- Authorisation based on the user's organisation
- Authorisation based on a bypass token

To apply any of the above authorisation protocols, the `draft` key must have a value of `true` in the request body sent to the
create or update asset API endpoints.

## Authorisation based on the user ID

To provide an allowlist of users that should be able to access an asset, include the `access_limited` key in the request body
when creating or updating an asset. The value should be an array of Signon user IDs. An empty array means "no restrictions of this type".

## Authorisation based on the user's organisation ID

To provide an allowlist of organisations whose users should be able to access an asset, include the `access_limited_organisation_ids` key in the request body
when creating or updating an asset. The value should be an array of organisation content IDs. An empty array means "no restrictions of this type".

## Authorisation based on a bypass token

Some publishing applications have a shareable preview feature, which allows publishers to share draft versions of content with
people that do not have a Signon account. The publishing app generates an authorisation bypass token, and the token ID can be
passed to asset manager to prevent general public access to the asset.

To apply bypass token authorisation to a draft asset, include the `auth_bypass_ids` key in the request body when creating or updating an
asset. The value should be an array of auth bypass token IDs. The value must be an array because publishing apps may create
multiple shareable preview links for a content item. An empty array means "no restrictions of this type". 


