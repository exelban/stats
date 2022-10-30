import subprocess
import re


def last_release_tag():
    cmd = "git describe --abbrev=0 --tags"
    output = subprocess.check_output(['bash', '-c', cmd])
    return output.decode("utf-8").strip()


def git_hash(tag):
    cmd = "git rev-list -n 1 {0}".format(tag)
    output = subprocess.check_output(['bash', '-c', cmd])
    return output.decode("utf-8").strip()


class Changelog:
    fixPattern = re.compile("^- fix:")
    featPattern = re.compile("^- feat:")
    langPattern = re.compile("^- lang:")

    def generate(self):
        tag = last_release_tag()
        tag_hash = git_hash(tag)

        fix, feat, lang = self.commits(tag_hash)

        changelog = ""

        if len(fix) != 0:
            changelog += "## Bug fixes \n{}".format("\n".join(fix))
        if len(feat) != 0:
            if len(changelog) != 0:
                changelog += "\n\n"
            changelog += "## New features \n{}".format("\n".join(feat))
        if len(lang) != 0:
            if len(changelog) != 0:
                changelog += "\n\n"
            changelog += "## Localization \n{}".format("\n".join(lang))

        print(changelog)

    def commits(self, first_commit):
        cmd = f"git log --pretty=\"- %s\" {first_commit}..HEAD"
        output = subprocess.check_output(['bash', '-c', cmd])
        lines = output.decode("utf-8").splitlines()

        fix = []
        feat = []
        lang = []

        for line in lines:
            if self.fixPattern.match(line) and "translation" not in line and "localization" not in line:
                fix.append(line)
            elif self.featPattern.match(line) and "translation" not in line and "localization" not in line:
                feat.append(line)
            elif self.langPattern.match(line) or "translation" in line or "localization" in line:
                lang.append(line)
            else:
                raise ValueError("Failed to detect commit {} type".format(line))

        return fix, feat, lang


if __name__ == "__main__":
    Changelog().generate()
