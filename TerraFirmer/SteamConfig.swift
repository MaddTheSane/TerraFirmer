//
//  SteamConfig.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/21/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

class SteamConfig {
	init() {
		
	}
}

/*
class SteamConfig {
class Element {
public:
QHash<QString, Element> children;
QString name, value;
Element();
explicit Element(QList<QString> *lines);
QString find(QString path);
};

public:
SteamConfig();
QString operator[](QString path) const;

private:
void parse(QString filename);
Element *root;
};
*/

/*
SteamConfig::SteamConfig() {
root = NULL;
QSettings settings("HKEY_CURRENT_USER\\Software\\Valve\\Steam",
QSettings::NativeFormat);
QString path = settings.value("SteamPath").toString();
if (path.isEmpty()) {
path =  QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)
.first();
path += QDir::toNativeSeparators("/Steam");
}
path += QDir::toNativeSeparators("/config/config.vdf");
QFile file(path);
if (file.exists())
parse(path);
}

QString SteamConfig::operator[](QString path) const {
if (root == NULL)
return QString();
return root->find(path);
}

void SteamConfig::parse(QString filename) {
QFile file(filename);

if (file.open(QIODevice::ReadOnly)) {
QList<QString> strings;
QTextStream in(&file);
while (!in.atEnd())
strings.append(in.readLine());
file.close();
root = new Element(&strings);
}
}

SteamConfig::Element::Element() {}

SteamConfig::Element::Element(QList<QString> *lines) {
QString line;
QRegularExpression re("\"([^\"]*)\"");
QRegularExpressionMatchIterator i;
while (lines->length() > 0) {
line = lines->front();
lines->pop_front();
i = re.globalMatch(line);
if (i.hasNext())
break;
}
if (!lines->length())  // corrupt
return;
QRegularExpressionMatch match = i.next();
name = match.captured(1).toLower();
if (i.hasNext()) {  // value is a string
match = i.next();
value = match.captured(1);
value.replace("\\\\", "\\");
}
line = lines->front();
if (line.contains("{")) {
lines->pop_front();
while (true) {
line = lines->front();
if (line.contains("}")) {  // empty
lines->pop_front();
return;
}
Element e(lines);
children[e.name] = e;
}
}
}

QString SteamConfig::Element::find(QString path) {
int ofs = path.indexOf("/");
if (ofs == -1)
return children[path].value;
return children[path.left(ofs)].find(path.mid(ofs + 1));
}

*/
