
# invite the users in the account and attach them to their access group
resource "ibm_iam_user_invite" "invite_user" {
  users         = ["mathias.mouly@fr.ibm.com"]
  access_groups = [ibm_iam_access_group.accgrp.id]
}
