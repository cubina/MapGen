import Foundation

public enum Winding:Printable{
		case CLOCKWISE
		case COUNTERCLOCKWISE
		case NONE
    
    public var description:String{
        switch(self){
        case CLOCKWISE:
            return "CLOCKWISE"
        case COUNTERCLOCKWISE:
            return "COUNTERCLOCKWISE"
        case NONE:
            return "NONE"
        }
    }
}


