# CHANGELOG

## Unreleased

* feat(bash): add review-prs [view commit](https://github.com/catenasys/shell-scripts/commit/fde4e007ab2a744729b6a751a36699f6b6a6d444)
* fix(bash): eksctl uses slightly different json syntax now [view commit](https://github.com/catenasys/shell-scripts/commit/22ee1821918983b17eef961f92ca4e5402934f01)
* fix(daml-export): add -z to set acs-batch-size [view commit](https://github.com/catenasys/shell-scripts/commit/7810afd38a514653c48a4b9c95d235f0e7a554ee)
* fix(daml-export): use DAML_PORT [view commit](https://github.com/catenasys/shell-scripts/commit/6a3fc9fbc5c238958765baf8ef939effdf34a8d1)
* fix(daml-export): use DAML_HOST [view commit](https://github.com/catenasys/shell-scripts/commit/d425a3f51bef53347f981041f72f279d734b6f2b)
* fix(daml-export): typo [view commit](https://github.com/catenasys/shell-scripts/commit/651bdb214f67c3b47dc122bee6ef867f1ef17935)
* fix(daml-export): /home/user references become HOME [view commit](https://github.com/catenasys/shell-scripts/commit/671d31312f6cc7bb40fb87b9ded9a426d2b1201b)
* fix(daml-export): add DAML_TOKEN arg parse [view commit](https://github.com/catenasys/shell-scripts/commit/136331e8492d07c07a8f9e68cfcb53a8cefcdb11)
* feat(bash): add daml-export [view commit](https://github.com/catenasys/shell-scripts/commit/d89241a791def6498efd9c4c58f98b9e764939ed)
* feat(kind-test-environment): update to use nginx-ingress [view commit](https://github.com/catenasys/shell-scripts/commit/11607f190b03f22b8d718eb8d4a0a447c35f1eea)
* feat(bash): add script to create a kind based test cluster [view commit](https://github.com/catenasys/shell-scripts/commit/8528ef45f7f1128cc0cbf46682287d3e58760f84)

## v0.1.9

* fix(git-check): always fetch origin if possible [view commit](https://github.com/catenasys/shell-scripts/commit/c8649acc9d21cc15fccadec893f43927e42d7e35)
* fix(bash): handle when cluster names contain '/' [view commit](https://github.com/catenasys/shell-scripts/commit/c3bf27b5cd6ccfb54ca26e74400a6a7910b1410d)

## v0.1.8

* fix(git-check): fetch before pull [view commit](https://github.com/catenasys/shell-scripts/commit/4d301e45e98bbf205fb00be9f0daae357c80027c)
* fix: change ADDITIONAL_NAMESPACES to string [view commit](https://github.com/catenasys/shell-scripts/commit/d18262340e03ed53635149ce613f4caa65f77f74)

## v0.1.7

* fix(bash): enhance update-repo-tags to detect annotated tags [view commit](https://github.com/catenasys/shell-scripts/commit/8ed4e340d5a1f8f3d0753eddfe05028da5a626b3)

## v0.1.6

* feat(changelog): add ability to extract ranges by date [view commit](https://github.com/catenasys/shell-scripts/commit/f8b08dcab3cbb83057ac408fb65da6c90bcf6149)
* feat(bash): add minikube-test-environment script [view commit](https://github.com/catenasys/shell-scripts/commit/f546287845592f94f17c73ffbda20fc1013bb88f)
* fix: simplifications to git-check [view commit](https://github.com/catenasys/shell-scripts/commit/d69be95a266b1b15621711782360adb0df74761e)

## v0.1.5

## v0.1.4

* fix(bash): update-repo-tags should add links when it gens changelog [view commit](https://github.com/catenasys/shell-scripts/commit/f6bb36ca7693a2de8701db0af6395f694f0c2fdf)
* feat(bash): add pagerduty-alert [view commit](https://github.com/catenasys/shell-scripts/commit/a90c756ee6730aa5f6f407496d14cbd9bd3bb871)
* feat(bash): add pagerduty-alert [view commit](https://github.com/catenasys/shell-scripts/commit/8b73b4f8e8913f36df3df8882c01474fee9e6d9d)
* feat(bash): add default incident dedup key [view commit](https://github.com/catenasys/shell-scripts/commit/57c03b28fd534f767a3eb7ea8cd5eb07c0ac4823)
* feat(bash): add pagerduty-alert [view commit](https://github.com/catenasys/shell-scripts/commit/782c57619e842dfaac1ffb9a6e1509607174a1ab)
* feat(bash): add pagerduty-alert [view commit](https://github.com/catenasys/shell-scripts/commit/eb09f6fc4afe6648594d434795cef55a54698403)
* feat(bash): add pagerduty-alert script [view commit](https://github.com/catenasys/shell-scripts/commit/291e492fe1ac2c9cfcdd66f858ac1aa6a234aedb)
* build: update pre-config-config [view commit](https://github.com/catenasys/shell-scripts/commit/d29849482e4803b8248ea840a777c77a0eb2ca73)
* fix(bash): changelog don't print an entry if there are no real changes [view commit](https://github.com/catenasys/shell-scripts/commit/ef41ece488f91cbe7c58c6b106ea89ff609af5c6)
* fix(bash): correct logging parameters [view commit](https://github.com/catenasys/shell-scripts/commit/307ce0d94431c8717d047eb2402b2cbd48fb6cb3)
* feat(bash): add the ability to collect from all NS [view commit](https://github.com/catenasys/shell-scripts/commit/49402e983915b0a372f84613ded393d43b6d063d)
* refactor(aliases): adjust aliases to use kubectl config directly [view commit](https://github.com/catenasys/shell-scripts/commit/7942c1589fde4407477d17d275302cea53c0429f)
* fix(update-repo-tags): replace Unreleased with new tag in changelog [view commit](https://github.com/catenasys/shell-scripts/commit/4c2aa9c944247cf77d26a5dbcf18f5bfcafc3c73)
* fix(git): correct git project url substitution [view commit](https://github.com/catenasys/shell-scripts/commit/1b583b9bc618ec6af3537ff571bc1c10e4c5a300)
* fix(mddoc): support empty markdown lines [view commit](https://github.com/catenasys/shell-scripts/commit/9fdb5f2d6da836d5c4771ac6cebc3f8cf6aaf053)
* feat(bash): add mddoc script for generically adding markdown inline via comments [view commit](https://github.com/catenasys/shell-scripts/commit/ae3aaa8dbb9461b38cd520b95e5e959246675c96)
* fix(docker): repo_tags_has compensate for dockerhub dropping real hostnames [view commit](https://github.com/catenasys/shell-scripts/commit/ddb5cab0d19e9be4ccf4a3ddd57c1d734ed2028c)
* fix(docker): cp_if_different always in promote_latest [view commit](https://github.com/catenasys/shell-scripts/commit/094a779803d922b31cc54c5ff88da8605f577ab8)
* fix(docker): add cp_if_different to optimize promotions [view commit](https://github.com/catenasys/shell-scripts/commit/e058809b696179d7c2880895e3dcb454ac8e28f5)
* fix(changelog): mark untagged changes in Unreleased [view commit](https://github.com/catenasys/shell-scripts/commit/d4d60dcf26195e3be9ffbf1fe0e829513e730614)
* fix(update-repo-tags): re-enable tagging [view commit](https://github.com/catenasys/shell-scripts/commit/96f0bed726c1da6b56aa7566cc61f1272b8f1c8b)
* feat(update-repo-tag): add option to generate and commit changelog [view commit](https://github.com/catenasys/shell-scripts/commit/e45461d129ef487bb322135671a1fcee55722481)
* fix(changelog): exclude ci changes from changelog [view commit](https://github.com/catenasys/shell-scripts/commit/944c0bc0a664d27a9436f23e9d7ab085ca1a4a33)

## v0.1.3

* fix(pack-script): dont shfmt scripts [view commit](https://github.com/catenasys/shell-scripts/commit/c9659b88ed60578e99c7c95f173736f38ab9bf52)
* build: pack scripts and create tar.gz files for doc, bin, and lib [view commit](https://github.com/catenasys/shell-scripts/commit/a93fb981431b906f238dc2f1967d3645efcfdce2)
* fix(pack-script): only look for @include at the start of a line [view commit](https://github.com/catenasys/shell-scripts/commit/320fd376a744a35d76fc7de66c65994e3a201cf6)
* fix(copy-keys): correct typo in key name [view commit](https://github.com/catenasys/shell-scripts/commit/efb1adbea3bed67af0f297c3bbe4105ecfc9b588)
* fix(aws-get-kubeconfigs): correct profile parameter passing [view commit](https://github.com/catenasys/shell-scripts/commit/d214e2e6a0c029988dc0ef97349f46fe44b172ad)
* fix: pull images before copy [view commit](https://github.com/catenasys/shell-scripts/commit/7a20f49ed4717d9f0f1c61fc7d8de587c97b081c)
* fix: enhance docker.sh to simulate and release-images to work off of a file [view commit](https://github.com/catenasys/shell-scripts/commit/5382a3472149b276237d4ffc383000b3a2a9622e)
* fix: incorrect parameters in docker::promote_latest [view commit](https://github.com/catenasys/shell-scripts/commit/e46952d7ec299dc06f8c3314641d91e82b9a6391)
* feat(docker): add the ability to simulate a promotion [view commit](https://github.com/catenasys/shell-scripts/commit/4a270e43d7249483892ae5f0d6c7263858c950b0)
* fix: correct checkout behavior [view commit](https://github.com/catenasys/shell-scripts/commit/de95390bf68c559dfdb045c2e406b39307a44d97)
* feat: add release-images script [view commit](https://github.com/catenasys/shell-scripts/commit/297a5877f8dca404a8eaf575efd45273d9fbf342)
* refactor: standardize on "private" method names [view commit](https://github.com/catenasys/shell-scripts/commit/b226d35be7354a71fb59121e621c298240bf9805)
* fix: correct typo in docker.sh [view commit](https://github.com/catenasys/shell-scripts/commit/236a04ce0910a0bab09f779eaecf9f9ef7bb2920)
* fix: include exec in docker.sh [view commit](https://github.com/catenasys/shell-scripts/commit/9fed31188ce63a3e74ad608d4e123005b2d07377)
* fix: enhance docker.sh facilities with release promotion related functions [view commit](https://github.com/catenasys/shell-scripts/commit/fa97d1fbe4764c121989132b1651edcf7caf4986)
* fix: correct commands error message [view commit](https://github.com/catenasys/shell-scripts/commit/b2a4f0359949a9bdbfe1167211861e0009c54b20)
* feat: add aws.sh [view commit](https://github.com/catenasys/shell-scripts/commit/01d3bdc6e070d533360db1189cc1d1715ba59ac5)
* fix: add documentation and secret::clear [view commit](https://github.com/catenasys/shell-scripts/commit/03d96f17649661052f4fe905be447fcf5b2042e7)
* feat: add secret.sh for safer handling of secrets [view commit](https://github.com/catenasys/shell-scripts/commit/42eff9ada3de71bc20c2922053c70cc0a2175480)

## v0.1.2

* refactor: update copyright notices [view commit](https://github.com/catenasys/shell-scripts/commit/87e5f8d2bc84f0cb980cb4dd736ac26b26b6b6f5)

## v0.1.1

* fix(update-repo-tags): correct semver location [view commit](https://github.com/catenasys/shell-scripts/commit/0a453d28d04617a36e5fb4237b548ec7e19e22ab)
* fix: give notices when pulling or dirty repository found [view commit](https://github.com/catenasys/shell-scripts/commit/71200d9ae8f29005de3aa0047f618ff6d271700a)
* fix: extract validator-debug.log files as well [view commit](https://github.com/catenasys/shell-scripts/commit/eb97cf73ba6d40a2d277f6559822d494f6eb7e83)
* build: pack scripts and fix cleanup [view commit](https://github.com/catenasys/shell-scripts/commit/e9b893b5f3d09aa329af0fb25a822da28dae06ee)
* build: add Makefile and ignore dist [view commit](https://github.com/catenasys/shell-scripts/commit/ac92c3c1456b01f1a9a0ff4155534469cc07c1e5)
* refactor: updates for documentation [view commit](https://github.com/catenasys/shell-scripts/commit/e8d29f6e38f8a518fd1731e2f4bd4247b4d17398)
* fix: correct annotation declaration and bashadoc [view commit](https://github.com/catenasys/shell-scripts/commit/612a1011208b7ed8709dd02fbdb2dbc6bd28a348)
