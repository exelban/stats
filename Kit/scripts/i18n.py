import os
import sys


def get_keys(elements):
    arr = []
    for el in elements:
        if el.startswith("//") or len(el) == 0 or el == "\n":
            continue
        key = el.replace("\n", "").split(" = ")[0].replace('"', "")
        arr.append(key)

    return arr


class i18n:
    path = os.getcwd() + "/Stats/Supporting Files/"

    def __init__(self):
        self.languages = list(filter(lambda x: x.endswith(".lproj"), os.listdir(self.path)))

    def en_file(self):
        en_file = open(f"{self.path}/en.lproj/Localizable.strings", "r").readlines()
        if en_file is None:
            sys.exit("English language not found.")
        return en_file

    def check(self):
        en_file = self.en_file()
        en_count = len(en_file)
        en_keys = get_keys(en_file)
        if len(en_keys) == 0:
            sys.exit("No English keys found.")

        for lang in self.languages:
            file = open(f"{self.path}/{lang}/Localizable.strings", "r").readlines()
            name = lang.replace(".lproj", "")
            keys = get_keys(file)
            if len(keys) == 0:
                sys.exit(f"No {name} keys found.")

            for i, el in enumerate(keys):
                if el != en_keys[i]:
                    sys.exit(f"missing or wrong key `{el}` in `{name}` on line `{i}`, must be `{en_keys[i]}`")

        print(f"All fine, found {en_count} lines in {len(self.languages)} languages.")

    def fix(self):
        pass


if __name__ == "__main__":
    i18n = i18n()
    if len(sys.argv) >= 2 and sys.argv[1] == "fix":
        print("running fix command...")
        i18n.fix()
    else:
        print("running check command...")
        i18n.check()

    print("done")
