# Copyright (C) 2019 baalajimaestro
# Licensed under the GNU GPL v3.0 License
# you may not use this file except in compliance with the License.
#
## Python backend to workaround for unofficial builds
## This would just clone all deps from the dependencies even when its an unofficial build

import json, os, subprocess

env = lambda var : os.environ.get(var)

with open("device/xiaomi/riva/komodo.dependencies") as deps:
	for dep in json.loads(deps.read()):
		repo = dep["repository"]
		path = dep["target_path"]
		branch = dep["branch"]
		remote = dep["remote"]
		if remote not in ("github", "gitlab"): raise Exception("Remote Derped!!")
		clone_cmd = "git clone --depth=1 https://%s.com/%s -b %s %s" % (remote, repo, branch, path)
		print("Cloning Repository", repo)
		clone = subprocess.run(clone_cmd.split(" "), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		print(clone.stdout.decode().strip(),clone.stderr.decode().strip())
