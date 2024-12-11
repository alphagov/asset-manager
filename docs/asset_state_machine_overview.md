## Asset state machine overview

Asset Manager stores a a number of fields whose values work together to represent the state of an asset.
These fields are closely related to various document states from the publishing applications.

1. `draft`

Assets are set to draft (boolean `true`) when they first get created on a draft edition. When the document gets published, the draft state of the asset should be updated to `false` by the publishing application.
All assets associated with live content must be publicly available. Once `draft` is set to `false`, it should not be set back to `true`. There are other ways to further represent that the asset is no longer live, such as setting a `redirect_url` or a `replacement_id`.

The draft state should always match the state of the `parent_document_url`. Recently, a [validation rule](https://github.com/alphagov/asset-manager/blob/cffce4e0e1323eab138e016de9b33536f62fef60/app/models/asset.rb#L288) has been added to ensure this, though no data patch was run for existing data.

Assets must be in draft for certain authorisation protocols to apply. See [documentation](https://github.com/alphagov/asset-manager/blob/cffce4e0e1323eab138e016de9b33536f62fef60/docs/authorisation.md).

2. `state`

This is a representation of the internal Asset Manager processing of the asset, particularly around uploading and virus scanning status.
The state machine includes `scanned_clean`, `clean`, `scanned_infected`, `upload_success`, `uploaded`.

NB: There are some invalid remnants of a previous state machine, including state values such as `deleted`, in the database. These should be removed.

3. `deleted_at`

The deletion timestamp should be set by the publishing application when an asset is deleted.
A `nil` value means the asset has not been deleted (default).

4. `replacement_id`

This is a BSON object ID, set by the publishing app when the user uploads a new file in the place of an old one, typically with the intention of preserving some contextual document metadata. 
Default is `nil`. The replaced asset redirects to its replacement, provided the replacement is not in draft.

Whilst deletion and replacements are mutually exclusive (an asset should not logically have both), they do coexist in the database.
Deletion, replacement, and draft work together to support previewing of draft content. An asset will not redirect to its replacement if the replacement is in draft.
This ensures that until the publish event is fired, the users can preview images and documents on the draft stack.

Publishing applications only send the next-in-line `replacement_id`. 
It is Asset Manager that deals with backpropagating the replacement - see the `update_indirect_replacements_on_publish` [callback](https://github.com/alphagov/asset-manager/blob/13d68aee4d0c8cf2c81be7fafef309dc36436ca3/app/models/asset.rb#L174).
This ensures that all assets in a chain of replacements redirect to the latest one.

5. `redirect_url`

This is set by the publishing app when the parent edition is unpublished. Default is `nil`. It is usually set to the parent document URL.
Upon creating a new draft of the parent edition, the publishing app should set the redirect URL back to `nil`.
