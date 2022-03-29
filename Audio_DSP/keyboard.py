from pynput.keyboard import Key, Listener
import numpy as np
import math as m
import simpleaudio as sa
import enum

fs = 8000

keynote = {
    'q': 0,
    'a': 1,
    'z': 2,
    'w': 3,
    's': 4,
    'x': 5,
    'e': 6,
    'd': 7,
    'c': 8,
    'r': 9,
    'f': 10,
    'v': 11,
    't': 12,
    'g': 13,
    'b': 14,
    'y': 15,
    'h': 16,
    'n': 17,
    'u': 18,
    'j': 19,
    'm': 20,
    'i': 21,
    'k': 22,
    'o': 23,
    'l': 24,
    'p': 25,
}

def init_key(f0, n = 26):
    global f_scale
    log_spacing = 1/12
    
    f_log = np.ndarray([n,1])
    f_scale = np.ndarray([n,1])
    
    f_log = np.linspace(f_log[0],(n-1)/12,n)
    f_scale = 2**f_log * f0
        
    return f_scale
    

def note(freq, len=1, amp=5000, rate=8000):
    t = np.linspace(0,len,int(len*rate),False)
    data = np.sin(2*np.pi*freq*t)*amp
    return data.astype(np.int16) # two byte integers


def play(key):
    global f_scale
    if len(str(key)) == 3:
        keystr = str(key)[1]
    else:
        keystr = 'na'
        
    if keystr in keynote:
        freq = f_scale[keynote[keystr]]
        print(f'You Entered {keystr}, freq: {freq}')
        data = note(freq, 0.25, 1000, fs)
        # Start playback
        play_obj = sa.play_buffer(data, 1, 2, fs)

        
    if key == Key.delete:
        # Wait for playback to finish before exiting
        play_obj.wait_done()
        # Stop listener
        return False
  

    
if __name__ == "__main__":
    
    init_key(110)
    
    # Collect all event until released
    with Listener(on_press = play) as listener:   
        listener.join()