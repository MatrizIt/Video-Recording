# capture.py

import sys
import cv2

def set_channel(indexCanal):
    cap = cv2.VideoCapture(0)  # Use o índice da câmera apropriado
    cap.set(cv2.CAP_PROP_CHANNEL, int(indexCanal))
    cap.release()

if __name__ == "__main__":
    set_channel(int(sys.argv[1]))
