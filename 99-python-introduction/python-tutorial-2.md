
# Python Tutorial 2

## If/Else Statements


```python
if 1 < 2:
    print("yes")
```

    yes



```python
if 1 < 2:
    print("yes")
else:
    print("no")
```

    yes



```python
if 1 < 2:
    print("yes")
elif 1 > 2:
    print("no")
else:
    print("whatever")
```

    yes


-----
## For Loops

#### Loop over a list and print each item


```python
seq = [1,2,3,4,5]
for item in seq:
    print(item)
```

    1
    2
    3
    4
    5


#### Loop over list without using item


```python
seq = [1,2,3,4,5]
for item in seq:
    print("Hello World!")
```

    Hello World!
    Hello World!
    Hello World!
    Hello World!
    Hello World!


-----
## While Loops


```python
i = 1

while i < 5:
    print("i is: {}".format(i))
    i = i + 1;
```

    i is: 1
    i is: 2
    i is: 3
    i is: 4


-----
## Miscellaneous

#### Create a list based on a range


```python
list(range(0,5))
```




    [0, 1, 2, 3, 4]



#### List Comprehensions


```python
x = [1,2,3,4]
[item**2 for item in x]
```




    [1, 4, 9, 16]



----
## Functions


```python
def myfunc(param1="default"):
    """
    Documentation of function goes here!
    """
    print(param1)
```


```python
myfunc()
```

    default



```python
myfunc("hello")
```

    hello


----
## Built-in Functions


```python
s = "Hello World! This is fun!"
```


```python
s.lower()
```




    'hello world! this is fun!'




```python
s.upper()
```




    'HELLO WORLD! THIS IS FUN!'



#### Split a string on whitespace


```python
s.split()
```




    ['Hello', 'World!', 'This', 'is', 'fun!']



#### Split on whitespace (explicitly specified)


```python
s.split(" ")
```




    ['Hello', 'World!', 'This', 'is', 'fun!']




```python

```
