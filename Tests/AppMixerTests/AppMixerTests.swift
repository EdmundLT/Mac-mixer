import XCTest
@testable import AppMixer
import AudioDSP
final class AppMixerTests:XCTestCase {
 func testChromeGrouping(){XCTAssertEqual(groupID("com.google.Chrome.helper"),"com.google.Chrome");XCTAssertEqual(groupID("com.google.Chrome.helper.renderer"),"com.google.Chrome");XCTAssertEqual(groupID("com.google.ChromeCanary"),"com.google.ChromeCanary")}
 func testSpotifyAndIndependentLevels(){var a=Level(),b=Level();a.volume=25;XCTAssertEqual(a.gain,0.25);XCTAssertEqual(b.gain,1);b.muted=true;XCTAssertEqual(b.gain,0);XCTAssertEqual(a.gain,0.25);b.muted=false;XCTAssertEqual(b.gain,1)}
 func testGainBounds(){var a=Level();a.volume = -5;XCTAssertEqual(a.gain,0);a.volume=200;XCTAssertEqual(a.gain,1)}
 func testDSPGainAndRamp(){let s=mixer_create()!;defer{mixer_free(s)};mixer_gain(s,0.5);var samples:[Float]=[1,1,1,1];var result=[Float](repeating:0,count:4);samples.withUnsafeMutableBytes{src in result.withUnsafeMutableBytes{dst in var input=AudioBufferList(mNumberBuffers:1,mBuffers:AudioBuffer(mNumberChannels:2,mDataByteSize:16,mData:src.baseAddress));var output=AudioBufferList(mNumberBuffers:1,mBuffers:AudioBuffer(mNumberChannels:2,mDataByteSize:16,mData:dst.baseAddress));var t=AudioTimeStamp();XCTAssertEqual(mixer_io(0,&t,&input,&t,&output,&t,UnsafeMutableRawPointer(s)),0)}};XCTAssertEqual(result,[0.75,0.75,0.5,0.5]);XCTAssertEqual(mixer_ticks(s),1);XCTAssertEqual(mixer_failed(s),0)}
}
