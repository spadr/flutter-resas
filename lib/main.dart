import 'dart:async';
import 'dart:convert';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

int prefectureCount = 0;
List isntLoad = [];
List isChecked = [];
List cache = [];

const String BASEURL = 'https://opendata.resas-portal.go.jp/api/v1';
const String KEY = String.fromEnvironment('API_KEY');
const Map<String, String>? HEADER = {'X-API-KEY': KEY};

Future<Resas> fetchResas(String endPoint, Map<String, String>? header, Map param) async {
  final http.Response response;
  if (param.isEmpty) {
    response = await http.get(Uri.parse(BASEURL + endPoint), headers: header);
    debugPrint('init');
    debugPrint(BASEURL + endPoint);
  } else {
    String params = '?';
    param.forEach((key, value) {
      params = params + key + '=' + value.toString() + '&';
    });
    params = params.substring(0, params.length - 1);
    response = await http.get(Uri.parse(BASEURL + endPoint + params), headers: header);
    debugPrint(BASEURL + endPoint + params);
  }

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return Resas.fromJson(jsonDecode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load');
  }
}

class Resas {
  final String? message;
  final dynamic result;

  const Resas({required this.message, required this.result});

  factory Resas.fromJson(Map<String, dynamic> json) {
    return Resas(message: json['message'], result: json['result']);
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Resas> futurePref;
  late Future<Resas> futurePopu;

  @override
  void initState() {
    super.initState();
    debugPrint(HEADER.toString());
    futurePref = fetchResas('/prefectures', HEADER, {});
    futurePref.then((value) {
      prefectureCount = value.result.length;
      isntLoad = List.filled(prefectureCount, true);
      isChecked = List.filled(prefectureCount, false);
      cache = List.filled(prefectureCount, []);
      debugPrint('fetchPopu');
    });
  }

  void fetchPopu(String endPoint, Map<String, String>? header, Map param, int index) {
    futurePopu = fetchResas(endPoint, header, param);
    futurePopu.then((value) {
      //List resData = [];
      List resData = value.result['data'][0]['data'];
      List<PopuData> popuList = [];
      for (var x in resData) {
        popuList.add(PopuData(DateTime(x['year'], 1, 1), x['value']));
      }
      cache[index] = popuList; //value.result['data'][0]['data'];
      debugPrint('fetchPopu');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Fetch Data Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Fetch Data Example'),
            ),
            body: Center(
              child: FutureBuilder<Resas>(
                future: futurePref,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                        itemCount: snapshot.data!.result.length,
                        itemBuilder: (context, index) {
                          return CheckboxListTile(
                            title: Text(snapshot.data!.result[index]['prefName'].toString()),
                            value: isChecked[snapshot.data!.result[index]['prefCode'] - 1],
                            onChanged: (bool? value) {
                              setState(() {
                                isChecked[snapshot.data!.result[index]['prefCode'] - 1] = value!;
                                if (isntLoad[snapshot.data!.result[index]['prefCode'] - 1]) {
                                  fetchPopu('/population/composition/perYear', HEADER, {'prefCode': snapshot.data!.result[index]['prefCode'], 'cityCode': '-'},
                                      snapshot.data!.result[index]['prefCode'] - 1);
                                }
                                isntLoad[snapshot.data!.result[index]['prefCode'] - 1] = false;
                                debugPrint(cache.toString());
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        });

                    //return Text(snapshot.data!.result[0].toString());

                  } else if (snapshot.hasError) {
                    return Text('${snapshot.error}');
                  }
                  // By default, show a loading spinner.
                  return const CircularProgressIndicator();
                },
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // "push"で新規画面に遷移
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) {
                    // 遷移先の画面としてリスト追加画面を指定
                    return const GraphPage();
                  }),
                );
              },
              child: const Icon(Icons.add),
            ),
          ),
        ));
  }
}

class PopuData {
  final DateTime year;
  final int value;

  PopuData(this.year, this.value);
}

class GraphPage extends StatelessWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('人口'),
            SizedBox(
              height: 500,
              child: charts.TimeSeriesChart(
                _createPopuData(cache),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<charts.Series<PopuData, DateTime>> _createPopuData(List cache) {
    List<charts.Series<PopuData, DateTime>> plot = [];
    for (var series in cache) {
      if (!series.isEmpty) {
        plot.add(charts.Series<PopuData, DateTime>(
          id: '都道府県',
          data: series,
          colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          domainFn: (PopuData popuData, _) => popuData.year,
          measureFn: (PopuData popuData, _) => popuData.value,
        ));
      }
    }
    return plot;
  }
}
