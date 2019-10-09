#!/bin/sh

# debug=0
# debug=1
debug=0

# -------------------------------------------------------------------------------------------------------------
# settings for remote handling
# -------------------------------------------------------------------------------------------------------------
# authentication_type=expect
# authentication_type=expect_create_new_ssh_rsa_key
# authentication_type=ssh_rsa_key
authentication_type=ssh_rsa_key

# remote_start_method=direct
# remote_start_method=cron
remote_start_method=cron

# remote_su_method=expect
# remote_su_method=sudo
remote_su_method=sudo

# supported combinations:
# -----------------------
# supported   authentication_type             remote_start_method     remote_su_method   remarks
# ----------------------------------------------------------------------------------------------
# yes         expect                          direct                  expect
# no          expect                          direct                  sudo
# no          expect                          cron                    expect
# yes         expect                          cron                    sudo               Only after expect_create_new_ssh_rsa_key
# yes         expect_create_new_ssh_rsa_key   direct                  expect
# no          expect_create_new_ssh_rsa_key   direct                  sudo
# no          expect_create_new_ssh_rsa_key   cron                    expect
# yes         expect_create_new_ssh_rsa_key   cron                    sudo
# no          ssh_rsa_key                     direct                  expect
# no          ssh_rsa_key                     direct                  sudo
# no          ssh_rsa_key                     cron                    expect
# yes         ssh_rsa_key                     cron                    sudo               Only after expect_create_new_ssh_rsa_key


# necessary for authentication_type: expect, expect_create_new_ssh_rsa_key
remote_connection_user=mgmadmin
remote_connection_password=sleposadmin

# necessary for remote_su_method: expect
remote_root_password=RundeSache
# -------------------------------------------------------------------------------------------------------------


maxslots=10
waitmaxslotending=600

# Minimum is 61
waittime=80

cleanupremotepath="N"








