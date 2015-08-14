import os
import re
import shutil

if __name__ == '__main__':

    print "START cleaning up data import folders"

    dir = r"/var/www/vhosts/provelobern-geomapfish/private/provelobern_bicyclerouteplanner/routing"
    
    dirmatch = next(os.walk(dir))
    subdirlist = dirmatch[1]
    p = re.compile('^[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}.*$')

    matchedsubdirlist = []
    for subdir in subdirlist:
      if p.match(subdir) is not None:
        matchedsubdirlist.append(subdir)
    
    count = len(matchedsubdirlist)
    if count > 3:
      print "more than 3 data folder, deleting old folders"
      matchedsubdirlist.sort()
      for matchedsubdir in matchedsubdirlist:
        if count > 3:
          path = os.path.join(dirmatch[0], matchedsubdir)
          print "deleting %s" % path
          shutil.rmtree(path)
        count -= 1
    print "END"
