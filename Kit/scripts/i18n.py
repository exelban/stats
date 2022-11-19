import os
import sys


def dictionary(lines):
    parsed_lines = {}
    for i, line in enumerate(lines):
        if line.startswith("//") or len(line) == 0 or line == "\n":
            continue
        line = line.replace("\n", "")
        pair = line.split(" = ")
        parsed_lines[i] = {
            "key": pair[0].replace('"', ""),
            "value": pair[1].replace('"', "").replace(';', "")
        }
    return parsed_lines


class i18n:
    path = os.getcwd() + "/Stats/Supporting Files/"

    def __init__(self):
        if "Kit/scripts" in os.getcwd():
            self.path = os.getcwd() + "/../../Stats/Supporting Files/"
        self.languages = list(filter(lambda x: x.endswith(".lproj"), os.listdir(self.path)))

    def en_file(self):
        en_file = open(f"{self.path}/en.lproj/Localizable.strings", "r").readlines()
        if en_file is None:
            sys.exit("English language not found.")
        return en_file

    def check(self):
        en_file = self.en_file()
        en_dict = dictionary(en_file)

        for lang in self.languages:
            file = open(f"{self.path}/{lang}/Localizable.strings", "r").readlines()
            name = lang.replace(".lproj", "")
            lang_dict = dictionary(file)

            for v in en_dict:
                en_key = en_dict[v].get("key")
                lang_ley = lang_dict[v].get("key")
                if lang_ley != en_key:
                    sys.exit(f"missing or wrong key `{lang_ley}` in `{name}` on line `{v}`, must be `{en_key}`")

        print(f"All fine, found {len(en_file)} lines in {len(self.languages)} languages.")

    def fix(self):
        en_file = self.en_file()
        en_dict = dictionary(en_file)

        for v in en_dict:
            en_key = en_dict[v].get("key")
            en_value = en_dict[v].get("value")

            for lang in self.languages:
                lang_path = f"{self.path}/{lang}/Localizable.strings"
                file = open(lang_path, "r").readlines()
                lang_dict = dictionary(file)

                if v not in lang_dict or en_key != lang_dict[v].get("key"):
                    file.insert(v, f"\"{en_key}\" = \"{en_value}\";\n")
                    with open(lang_path, "w") as f:
                        file = "".join(file)
                        f.write(file)
                        f.close()

        self.check()


if __name__ == "__main__":
    i18n = i18n()
    if len(sys.argv) >= 2 and sys.argv[1] == "fix":
        print("running fix command...")
        i18n.fix()
    else:
        print("running check command...")
        i18n.check()

    print("done")
