#! /usr/bin/env python

# from gitosis@projects.france-bioinformatique.fr:cloudweb.git
# path /cloudweb/rainbio2/tool_shed.py


def add_in_json_command(json_string, key, value, print_values=False):
    """
    Modify a json entered as string such that the key is associated at depth 0 to the given value

    Args:
        :param json_string: json data as a string or a blank string
        :param key: the key for which we want to add the value
        :param value: teh value itself
        :param print_values: print to stdout the returned value(s)

    Returns:
        the json modified such as the key is associated at depth 0 to the given value

    """
    import json
    try:
        data = json.loads(json_string)
    except ValueError as e:
        data = {}
    data.update({key: value})
    data = json.dumps(data)
    if print_values:
        print data
    return data


def find_in_json_command(json_string, key, recursive=False, return_all=False, separator=",", print_values=False):
    """
    Find one or more values associated to a given key in a json given as a string.

    Args:
        :param json_string: json data as a string
        :param key: the key for which we want the value(s)
        :param recursive: search for the key not only at depth 0
        :param return_all: search for all entry with that key
        :param separator: char to separate the entries
        :param print_values: print to stdout the returned value(s)

    Returns: value(s) associated to the given key

    """
    import json
    try:
        data = json.loads(json_string)
    except ValueError as e:
        print e.message
        print "A json string looks like:"
        print json.dumps({'t': {'k': 1, 'y': 2}, 'u': {'k': 12, 'y': 22}, 'k': 3})
        return ""
    ret = []
    if key in data.keys():
        ret.append(str(data[key]))
    if (return_all or len(ret) == 0) and recursive:
        for v in data.values():
            found = search_in_json_content(key, v, return_all)
            if found is not None:
                if return_all:
                    for r in found:
                        ret.append(str(r))
                else:
                    if print_values:
                        print found
                    return found

    final_str = separator.join(ret)
    if print_values:
        print final_str
    return final_str


def search_in_json_content(keyword, json_content, return_all=False):
    '''
    find and return the first value corresponding to the keyword entered.
    It's a recursive function.
    If nothing is found the object returned will be None.
    - keyword : must be a string
    - json_content : can be a list or a dictionnary (whatever)
    '''
    # print "\tjson class"
    # print "\t\t"+str(json_content.__class__)+"\n"

    values = []

    # if the json_content argument is a list then
    if json_content.__class__ == list:
        # for each element
        for element in json_content:
            # call this function and if something else than None is returned, stop the loop
            res = search_in_json_content(keyword, element)
            if res is not None:
                if not return_all:
                    return res
                for v in res:
                    values.append(v)
    # if the json_content argument is a dictionnary then
    elif json_content.__class__ == dict:
        # for each key check if the key is the keyword
        for key in json_content.keys():
            # if it's not the case, call this function on whatever is the value of the key (and stop it if there is a result)
            if key != keyword:
                res = search_in_json_content(keyword, json_content[key])
                if res is not None:
                    if not return_all:
                        return res
                    for v in res:
                        values.append(v)
                        break
            # if the key is the keyword : hurra! you found your stuff! just return the result and stop the loop
            else:
                if not return_all:
                    return json_content[key]
                values.append(json_content[key])
    if return_all:
        return values
    return None


if __name__ == '__main__':
    import scriptine

    scriptine.run()
